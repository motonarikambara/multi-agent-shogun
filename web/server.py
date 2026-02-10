#!/usr/bin/env python3
"""
Paper Writing System - Web Dashboard Server

Real-time dashboard for monitoring Author-Reviewer interactions.
Uses Flask + Flask-SocketIO for WebSocket support.
"""

import os
import yaml
import time
import subprocess
import threading
import platform
from pathlib import Path
from datetime import datetime
from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
from watchdog.observers import Observer
from watchdog.observers.polling import PollingObserver
from watchdog.events import FileSystemEventHandler

# Configuration
BASE_DIR = Path(__file__).parent.parent
QUEUE_DIR = BASE_DIR / "queue"
CONTEXT_DIR = BASE_DIR / "context"
CONFIG_DIR = BASE_DIR / "config"

app = Flask(__name__)
app.config['SECRET_KEY'] = 'paper-writing-system-secret'
socketio = SocketIO(app, cors_allowed_origins="*")

# Track server start time for startup grace period
_server_start_time = time.time()

# File watcher for real-time updates
class QueueFileHandler(FileSystemEventHandler):
    """Watch queue directory for changes and emit updates."""
    
    def __init__(self, socketio):
        self.socketio = socketio
        self.last_emit = {}
        
    def on_modified(self, event):
        if event.is_directory:
            return
        if not event.src_path.endswith(('.yaml', '.yml')):
            return
            
        # Debounce: don't emit more than once per second per file
        now = time.time()
        if event.src_path in self.last_emit:
            if now - self.last_emit[event.src_path] < 1:
                return
        self.last_emit[event.src_path] = now
        
        # Emit update
        self.socketio.emit('file_updated', {
            'file': os.path.basename(event.src_path),
            'path': event.src_path,
            'timestamp': datetime.now().isoformat()
        })
        
        # Also emit the full state
        self.socketio.emit('state_updated', get_current_state())


def load_yaml_safe(path):
    """Safely load a YAML file, returning empty dict on error."""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
            if not content.strip():
                return {}
            return yaml.safe_load(content) or {}
    except Exception as e:
        return {'error': str(e)}


def get_current_state():
    """Get the current state of all queue files."""
    state = {
        'timestamp': datetime.now().isoformat(),
        'draft': None,
        'reviews': {},
        'control': None,
        'history': []
    }
    
    # Load draft
    draft_path = QUEUE_DIR / "draft" / "current.yaml"
    if draft_path.exists():
        state['draft'] = load_yaml_safe(draft_path)
    
    # Load reviews
    reviews_dir = QUEUE_DIR / "reviews"
    if reviews_dir.exists():
        for i in range(1, 4):
            review_path = reviews_dir / f"reviewer{i}.yaml"
            if review_path.exists():
                state['reviews'][f'reviewer{i}'] = load_yaml_safe(review_path)
    
    # Load control
    control_path = QUEUE_DIR / "control.yaml"
    if control_path.exists():
        state['control'] = load_yaml_safe(control_path)
    
    # Load history
    history_path = QUEUE_DIR / "rebuttal" / "history.yaml"
    if history_path.exists():
        state['history'] = load_yaml_safe(history_path)
    
    return state


def get_context_files():
    """Get context files (habits, glossary, references)."""
    context = {}
    
    # Load habits
    habits_path = CONTEXT_DIR / "author_habits.yaml"
    if habits_path.exists():
        context['habits'] = load_yaml_safe(habits_path)
    
    # Load glossary
    glossary_path = CONTEXT_DIR / "glossary.yaml"
    if glossary_path.exists():
        context['glossary'] = load_yaml_safe(glossary_path)
    
    # Load references (markdown)
    references_path = CONTEXT_DIR / "references.md"
    if references_path.exists():
        try:
            with open(references_path, 'r', encoding='utf-8') as f:
                context['references'] = f.read()
        except:
            context['references'] = ""
    
    return context


# Routes
@app.route('/')
def index():
    """Serve the dashboard."""
    return render_template('index.html')


@app.route('/api/state')
def api_state():
    """Get current state as JSON."""
    return jsonify(get_current_state())


@app.route('/api/context')
def api_context():
    """Get context files as JSON."""
    return jsonify(get_context_files())


@app.route('/api/context/references', methods=['POST'])
def api_update_references():
    """Update references.md from the web UI."""
    data = request.get_json(silent=True) or {}
    content = data.get('content', '')
    references_path = CONTEXT_DIR / "references.md"
    references_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(references_path, 'w', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

    socketio.emit('context_updated', get_context_files())
    return jsonify({'success': True})


@app.route('/api/reset', methods=['POST'])
def api_reset():
    """Reset all state: queue, paper, habits, glossary. Keep references."""
    errors = []
    
    # Reset queue/draft/current.yaml
    try:
        draft_path = QUEUE_DIR / "draft" / "current.yaml"
        draft_path.parent.mkdir(parents=True, exist_ok=True)
        with open(draft_path, 'w') as f:
            f.write("# Current Draft\nparagraph:\n  id: null\n  question: null\n  answer: null\n  target_section: null\n  draft: null\n  status: idle\n  round: 0\n  timestamp: \"\"\n  rebuttal: null\n")
    except Exception as e:
        errors.append(f"draft: {e}")
    
    # Reset queue/reviews/reviewer*.yaml
    for i in range(1, 4):
        try:
            rp = QUEUE_DIR / "reviews" / f"reviewer{i}.yaml"
            rp.parent.mkdir(parents=True, exist_ok=True)
            with open(rp, 'w') as f:
                f.write(f"# Reviewer {i} Review\nreview:\n  paragraph_id: null\n  reviewer_id: reviewer{i}\n  round: 0\n  decision: null\n  timestamp: \"\"\n  overall_assessment: null\n  consistency_with_paper: null\n  comments: []\n")
        except Exception as e:
            errors.append(f"reviewer{i}: {e}")
    
    # Reset queue/rebuttal/history.yaml
    try:
        hp = QUEUE_DIR / "rebuttal" / "history.yaml"
        hp.parent.mkdir(parents=True, exist_ok=True)
        with open(hp, 'w') as f:
            f.write("# Rebuttal History\nhistory: []\n")
    except Exception as e:
        errors.append(f"history: {e}")
    
    # Reset queue/control.yaml
    try:
        cp = QUEUE_DIR / "control.yaml"
        with open(cp, 'w') as f:
            f.write("# User Intervention Control File\ncommand: null\nredirect_instruction: \"\"\nskip_reviewers: []\nuser_comment: \"\"\nlast_updated: null\n")
    except Exception as e:
        errors.append(f"control: {e}")
    
    # Reset context/author_habits.yaml
    try:
        habits_path = CONTEXT_DIR / "author_habits.yaml"
        with open(habits_path, 'w') as f:
            f.write("# Author Habits\nbad_habits: []\nuser_preferences: []\n")
    except Exception as e:
        errors.append(f"habits: {e}")
    
    # Reset context/glossary.yaml
    try:
        glossary_path = CONTEXT_DIR / "glossary.yaml"
        with open(glossary_path, 'w') as f:
            f.write("# Glossary\nterminology: {}\nnotation: {}\nclaims: {}\n")
    except Exception as e:
        errors.append(f"glossary: {e}")
    
    # Clear paper/ (all .tex files in sections, drafts.md, but keep main.tex template)
    paper_dir = BASE_DIR / "paper"
    sections_dir = paper_dir / "sections"
    try:
        if sections_dir.exists():
            for f in sections_dir.glob("*.tex"):
                f.unlink()
    except Exception as e:
        errors.append(f"sections: {e}")
    
    try:
        drafts_path = paper_dir / "drafts.md"
        if drafts_path.exists():
            drafts_path.unlink()
    except Exception as e:
        errors.append(f"drafts.md: {e}")
    
    # Emit updated state to all clients
    socketio.emit('state_updated', get_current_state())
    socketio.emit('context_updated', get_context_files())
    
    if errors:
        return jsonify({'success': False, 'errors': errors}), 500
    return jsonify({'success': True})


@app.route('/api/settings')
def api_settings():
    """Get current settings."""
    settings_path = CONFIG_DIR / "settings.yaml"
    if settings_path.exists():
        return jsonify(load_yaml_safe(settings_path))
    return jsonify({})


@app.route('/api/settings/model', methods=['GET', 'POST'])
def api_model():
    """Get or set the current model."""
    settings_path = CONFIG_DIR / "settings.yaml"
    
    if request.method == 'GET':
        settings = load_yaml_safe(settings_path) if settings_path.exists() else {}
        current_model = settings.get('models', {}).get('current', 'opus')
        available_models = settings.get('models', {}).get('available', ['opus', 'sonnet'])
        return jsonify({
            'current': current_model,
            'available': available_models
        })
    
    elif request.method == 'POST':
        data = request.get_json()
        new_model = data.get('model', 'opus')
        
        # Validate model
        if new_model not in ['opus', 'sonnet']:
            return jsonify({'error': 'Invalid model. Use opus or sonnet.'}), 400
        
        # Update settings.yaml
        settings = load_yaml_safe(settings_path) if settings_path.exists() else {}
        if 'models' not in settings:
            settings['models'] = {}
        settings['models']['current'] = new_model
        
        with open(settings_path, 'w', encoding='utf-8') as f:
            yaml.dump(settings, f, default_flow_style=False, allow_unicode=True)
        
        # Emit update to all clients
        socketio.emit('settings_updated', {'models': settings['models']})
        
        # Auto-restart agents with new model in background
        threading.Thread(target=_restart_agents, args=(new_model,), daemon=True).start()
        
        return jsonify({
            'status': 'success',
            'model': new_model,
            'message': f'Model changed to {new_model}. Agents restarting...'
        })


def _restart_agents(model: str) -> str:
    """Restart all Claude agents in tmux with the given model.
    
    Returns empty string on success, error message on failure.
    """
    panes = ['paper:0.0', 'paper:0.1', 'paper:0.2', 'paper:0.3']
    labels = ['author', 'reviewer1', 'reviewer2', 'reviewer3']
    instructions = [
        'Read instructions/author.md and understand your role.',
        'Read instructions/reviewer.md and understand your role. You are reviewer1.',
        'Read instructions/reviewer.md and understand your role. You are reviewer2.',
        'Read instructions/reviewer.md and understand your role. You are reviewer3.',
    ]
    try:
        # Send /exit to each pane to quit current Claude session
        for pane in panes:
            subprocess.run(['tmux', 'send-keys', '-t', pane, '/exit'], capture_output=True)
            subprocess.run(['tmux', 'send-keys', '-t', pane, 'Enter'], capture_output=True)
        
        time.sleep(2)
        
        # Start Claude with new model in each pane
        for pane in panes:
            cmd = f'claude --model {model} --dangerously-skip-permissions'
            subprocess.run(['tmux', 'send-keys', '-t', pane, cmd], capture_output=True)
            subprocess.run(['tmux', 'send-keys', '-t', pane, 'Enter'], capture_output=True)
            time.sleep(0.5)
        
        # Wait for disclaimer and accept it
        time.sleep(5)
        for pane in panes:
            output = capture_tmux_pane(pane, 30)
            if 'Yes, I accept' in output:
                subprocess.run(['tmux', 'send-keys', '-t', pane, 'Down'], capture_output=True)
                time.sleep(0.3)
                subprocess.run(['tmux', 'send-keys', '-t', pane, 'Enter'], capture_output=True)
        
        # Wait for Claude to be ready, then send instructions
        time.sleep(10)
        for i, pane in enumerate(panes):
            subprocess.run(['tmux', 'send-keys', '-t', pane, instructions[i]], capture_output=True)
            time.sleep(0.5)
            subprocess.run(['tmux', 'send-keys', '-t', pane, 'Enter'], capture_output=True)
            time.sleep(2)
        
        return ''
    except Exception as e:
        return str(e)


# WebSocket events
@socketio.on('connect')
def handle_connect():
    """Send current state on connect."""
    emit('state_updated', get_current_state())
    emit('context_updated', get_context_files())
    emit('terminals_updated', get_all_pane_outputs())


@socketio.on('request_state')
def handle_request_state():
    """Handle explicit state request."""
    emit('state_updated', get_current_state())


@socketio.on('request_context')
def handle_request_context():
    """Handle explicit context request."""
    emit('context_updated', get_context_files())


def capture_tmux_pane(pane: str, lines: int = 100) -> str:
    """Capture the content of a tmux pane.
    
    Args:
        pane: Target pane (e.g., 'paper:0.0')
        lines: Number of lines to capture
        
    Returns:
        The pane content as a string
    """
    try:
        result = subprocess.run(
            ['tmux', 'capture-pane', '-t', pane, '-p', '-S', f'-{lines}'],
            capture_output=True,
            text=True
        )
        return result.stdout
    except Exception as e:
        return f"Error capturing pane: {e}"


def get_all_pane_outputs() -> dict:
    """Get the output from all agent panes."""
    panes = {
        'author': 'paper:0.0',
        'reviewer1': 'paper:0.1',
        'reviewer2': 'paper:0.2',
        'reviewer3': 'paper:0.3',
    }
    
    outputs = {}
    for name, pane in panes.items():
        outputs[name] = capture_tmux_pane(pane, 50)
    
    return outputs


def is_claude_running(pane: str) -> bool:
    """Check if Claude Code is actually running and ready in a tmux pane.
    
    Must distinguish between:
    - Shell has 'claude' typed as a command (NOT ready)
    - Claude Code is actually running and accepting input (ready)
    """
    try:
        output = capture_tmux_pane(pane, 30)
        if not output or not output.strip():
            return False
        
        # Get the last few non-empty lines
        lines = [l for l in output.strip().splitlines() if l.strip()]
        if not lines:
            return False
        
        last_line = lines[-1].strip()
        
        # Claude Code's interactive prompt is '❯' (at the start of a line)
        # This only appears when Claude is ready for user input
        if last_line == '❯' or last_line.endswith('❯'):
            return True
        
        # Claude is actively thinking/processing (spinner, "thinking", etc.)
        if any(kw in output for kw in ['thinking', 'Churned', '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']):
            return True
        
        # If the last line is a bare shell prompt (% or $), Claude is NOT running
        if last_line.endswith('%') or last_line.endswith('$'):
            return False
        
        # If we see "claude" only in a command being typed/executed, it's NOT ready
        # (e.g., "claude --model opus --dangerously-skip-permissions")
        if 'claude --model' in output or 'dangerously-skip-permissions' in output:
            # Check if Claude has actually started (look for its UI elements)
            if '❯' not in output and 'tips:' not in output:
                return False
        
        # Default: assume NOT running (safe - prevents sending to shell)
        return False
    except Exception:
        return False


def send_to_tmux(pane: str, message: str) -> dict:
    """Send a message to a tmux pane.
    
    Args:
        pane: Target pane (e.g., 'paper:0.0' for author)
        message: Message to send
        
    Returns:
        dict with success status and any error message
    """
    # Safety check: don't send to bare shell
    if not is_claude_running(pane):
        return {
            'success': False,
            'error': 'Claude Code is not running in this pane. Start agents first (./start.sh --web).'
        }

    try:
        # Send the message
        subprocess.run(
            ['tmux', 'send-keys', '-t', pane, message],
            check=True,
            capture_output=True
        )
        # Send Enter
        subprocess.run(
            ['tmux', 'send-keys', '-t', pane, 'Enter'],
            check=True,
            capture_output=True
        )
        return {'success': True}
    except subprocess.CalledProcessError as e:
        return {'success': False, 'error': e.stderr.decode()}
    except Exception as e:
        return {'success': False, 'error': str(e)}


@socketio.on('send_message')
def handle_send_message(data):
    """Handle message from browser to send to an agent."""
    target = data.get('target', 'author')
    message = data.get('message', '')
    
    if not message.strip():
        emit('message_result', {'success': False, 'error': 'Empty message'})
        return
    
    # Reject messages during startup grace period (first 10 seconds)
    # This prevents replayed Socket.IO events from reaching shell prompts
    elapsed = time.time() - _server_start_time
    if elapsed < 10:
        emit('message_result', {
            'success': False,
            'error': f'Server starting up. Wait {int(10 - elapsed)}s for agents to initialize.'
        })
        return
    
    # Map target names to tmux panes
    pane_map = {
        'author': 'paper:0.0',
        'reviewer1': 'paper:0.1',
        'reviewer2': 'paper:0.2',
        'reviewer3': 'paper:0.3',
    }
    
    pane = pane_map.get(target, 'paper:0.0')
    result = send_to_tmux(pane, message)
    
    # Log the message
    socketio.emit('message_sent', {
        'target': target,
        'message': message,
        'timestamp': datetime.now().isoformat(),
        'success': result['success']
    })
    
    emit('message_result', result)


@app.route('/api/send', methods=['POST'])
def api_send():
    """REST API to send message to agent."""
    data = request.json
    target = data.get('target', 'author')
    message = data.get('message', '')
    
    # Reject during startup grace period
    elapsed = time.time() - _server_start_time
    if elapsed < 10:
        return jsonify({
            'success': False,
            'error': f'Server starting up. Wait {int(10 - elapsed)}s for agents to initialize.'
        }), 503
    
    pane_map = {
        'author': 'paper:0.0',
        'reviewer1': 'paper:0.1',
        'reviewer2': 'paper:0.2',
        'reviewer3': 'paper:0.3',
    }
    
    pane = pane_map.get(target, 'paper:0.0')
    result = send_to_tmux(pane, message)
    return jsonify(result)


@app.route('/api/terminals')
def api_terminals():
    """Get all terminal outputs."""
    return jsonify(get_all_pane_outputs())


@socketio.on('request_terminals')
def handle_request_terminals():
    """Handle request for terminal outputs."""
    emit('terminals_updated', get_all_pane_outputs())


# Background task for terminal updates
terminal_update_running = False

def terminal_update_loop():
    """Background loop to send terminal updates using SocketIO's background task."""
    global terminal_update_running
    last_outputs = {}
    
    while terminal_update_running:
        try:
            outputs = get_all_pane_outputs()
            # Only emit if there are changes
            if outputs != last_outputs:
                socketio.emit('terminals_updated', outputs, namespace='/')
                last_outputs = outputs.copy()
        except Exception as e:
            print(f"Terminal update error: {e}")
        
        socketio.sleep(1)  # Use socketio.sleep for compatibility with eventlet


def start_terminal_updates():
    """Start the background task for terminal updates."""
    global terminal_update_running
    terminal_update_running = True
    socketio.start_background_task(terminal_update_loop)


def stop_terminal_updates():
    """Stop the background task."""
    global terminal_update_running
    terminal_update_running = False


def start_file_watcher():
    """Start watching queue directory for changes."""
    event_handler = QueueFileHandler(socketio)
    # Use polling on macOS to avoid FSEvents stream issues
    if platform.system() == "Darwin":
        observer = PollingObserver()
    else:
        observer = Observer()
    
    # Watch queue directory
    observer.schedule(event_handler, str(QUEUE_DIR), recursive=True)
    
    # Also watch context directory
    observer.schedule(event_handler, str(CONTEXT_DIR), recursive=True)
    
    observer.start()
    return observer


def main():
    """Run the server."""
    import argparse
    parser = argparse.ArgumentParser(description='Paper Writing System Dashboard')
    parser.add_argument('--host', default='127.0.0.1', help='Host to bind to')
    parser.add_argument('--port', type=int, default=5000, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    args = parser.parse_args()
    
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║  Paper Writing System - Web Dashboard                        ║
║                                                              ║
║  Dashboard: http://{args.host}:{args.port}                          ║
║                                                              ║
║  Real-time terminal output + WebSocket updates               ║
║  No need to attach to tmux - everything in browser!          ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    # Start file watcher in background
    observer = start_file_watcher()
    
    # Start terminal update loop
    start_terminal_updates()
    
    try:
        socketio.run(app, host=args.host, port=args.port, debug=args.debug)
    finally:
        stop_terminal_updates()
        observer.stop()
        observer.join()


if __name__ == '__main__':
    main()

