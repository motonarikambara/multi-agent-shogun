#!/bin/bash
# Paper Writing System - Multi-Agent Academic Writing Framework
# Startup Script
#
# Usage:
#   ./start.sh           # Start all agents
#   ./start.sh -c        # Reset queue and start (clean start)
#   ./start.sh -s        # Setup only (no Claude startup)
#   ./start.sh -h        # Show help

# set -e removed: many commands intentionally fail (tmux kill, grep, etc.)

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# Platform detection
# ═══════════════════════════════════════════════════════════════════════════════
detect_platform() {
    case "$(uname -s)" in
        Darwin*)    PLATFORM="macos" ;;
        Linux*)     PLATFORM="linux" ;;
        CYGWIN*|MINGW*|MSYS*) PLATFORM="windows" ;;
        *)          PLATFORM="unknown" ;;
    esac
}
detect_platform

# uv detection (for Python environment management)
detect_uv() {
    if command -v uv &>/dev/null; then
        UV_AVAILABLE=true
    else
        UV_AVAILABLE=false
    fi
}

# Python command detection (python3 or python)
detect_python() {
    if command -v python3 &>/dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &>/dev/null; then
        # Check if python is Python 3
        if python --version 2>&1 | grep -q "Python 3"; then
            PYTHON_CMD="python"
        else
            echo "Error: Python 3 is required but not found"
            exit 1
        fi
    else
        echo "Error: Python 3 is required but not found"
        echo ""
        if [ "$PLATFORM" = "macos" ]; then
            echo "Install with: brew install python3"
        elif [ "$PLATFORM" = "linux" ]; then
            echo "Install with: sudo apt install python3"
        fi
        exit 1
    fi
}

detect_uv

# Check required dependencies
check_dependencies() {
    local missing=()
    
    # Check tmux
    if ! command -v tmux &>/dev/null; then
        missing+=("tmux")
    fi
    
    # Check claude CLI
    if ! command -v claude &>/dev/null; then
        missing+=("claude (Claude Code CLI)")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        if [ "$PLATFORM" = "macos" ]; then
            echo "Install tmux with: brew install tmux"
        elif [ "$PLATFORM" = "linux" ]; then
            echo "Install tmux with: sudo apt install tmux"
        fi
        echo "Install Claude Code CLI: https://claude.ai/code"
        exit 1
    fi
}

check_claude_login() {
    # Try to detect login status without triggering interactive login
    local output=""
    if output=$(claude auth status 2>&1); then
        # Command succeeded - check for negative indicators
        if echo "$output" | grep -qiE "not logged|not authenticated|login required|please log in"; then
            echo "Error: Claude Code CLI is not logged in."
            echo "Run: claude auth login"
            exit 1
        fi
        # Command succeeded and no negative keywords → assume logged in
        return 0
    fi

    # auth status failed - try whoami as fallback
    output=$(claude whoami 2>&1 || true)
    if echo "$output" | grep -qiE "not logged|not authenticated|login required|please log in"; then
        echo "Error: Claude Code CLI is not logged in."
        echo "Run: claude auth login"
        exit 1
    fi

    # Check for positive indicators in whoami output
    if echo "$output" | grep -qiE "@|logged in|authenticated|user:"; then
        return 0
    fi

    # Cannot determine status - warn but don't block
    log_info "Warning: Could not verify Claude CLI login status."
    log_info "If login fails, run: claude auth login"
}

# Read shell setting (default: bash on Linux, zsh on macOS)
if [ "$PLATFORM" = "macos" ]; then
    DEFAULT_SHELL="zsh"
else
    DEFAULT_SHELL="bash"
fi

SHELL_SETTING="$DEFAULT_SHELL"
if [ -f "./config/settings.yaml" ]; then
    SHELL_SETTING=$(grep "^shell:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "$DEFAULT_SHELL")
fi

# Colored log functions
log_info() {
    echo -e "\033[1;33m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[OK]\033[0m $1"
}

log_action() {
    echo -e "\033[1;36m[ACTION]\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Prompt generation function (bash/zsh compatible)
# ═══════════════════════════════════════════════════════════════════════════════
generate_prompt() {
    local label="$1"
    local color="$2"
    local shell_type="$3"

    if [ "$shell_type" == "zsh" ]; then
        echo "(%F{${color}}%B${label}%b%f) %F{green}%B%~%b%f%# "
    else
        local color_code
        case "$color" in
            red)     color_code="1;31" ;;
            green)   color_code="1;32" ;;
            yellow)  color_code="1;33" ;;
            blue)    color_code="1;34" ;;
            magenta) color_code="1;35" ;;
            cyan)    color_code="1;36" ;;
            *)       color_code="1;37" ;;
        esac
        echo "(\[\033[${color_code}m\]${label}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ "
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Option parsing
# ═══════════════════════════════════════════════════════════════════════════════
SETUP_ONLY=false
CLEAN_MODE=false
SHELL_OVERRIDE=""
WEB_MODE=false
WEB_PORT=5050
CLAUDE_MODEL="opus"  # Default model: opus, sonnet

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--setup-only)
            SETUP_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        -w|--web)
            WEB_MODE=true
            shift
            ;;
        -p|--port)
            if [[ -n "$2" && "$2" != -* ]]; then
                WEB_PORT="$2"
                shift 2
            else
                echo "Error: -p option requires a port number"
                exit 1
            fi
            ;;
        -shell|--shell)
            if [[ -n "$2" && "$2" != -* ]]; then
                SHELL_OVERRIDE="$2"
                shift 2
            else
                echo "Error: -shell option requires bash or zsh"
                exit 1
            fi
            ;;
        -m|--model)
            if [[ -n "$2" && "$2" != -* ]]; then
                CLAUDE_MODEL="$2"
                shift 2
            else
                echo "Error: -m option requires model name (opus, sonnet)"
                exit 1
            fi
            ;;
        -h|--help)
            echo ""
            echo "Paper Writing System - Multi-Agent Academic Writing Framework"
            echo ""
            echo "Usage: ./start.sh [options]"
            echo ""
            echo "Options:"
            echo "  -c, --clean         Reset queue and start (clean start)"
            echo "  -s, --setup-only    Setup tmux session only (no Claude startup)"
            echo "  -w, --web           Start web dashboard (browser mode)"
            echo "  -p, --port PORT     Web dashboard port (default: 5000)"
            echo "  -m, --model MODEL   Claude model to use (opus, sonnet; default: opus)"
            echo "  -shell, --shell SH  Specify shell (bash or zsh)"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Modes:"
            echo "  Terminal only:    ./start.sh"
            echo "  Terminal + Web:   ./start.sh --web"
            echo "  Web only:         ./start.sh --web --setup-only"
            echo ""
            echo "Agent Configuration:"
            echo "  Author:     Writes paper paragraphs"
            echo "  Reviewer 1: Contributions & Claims"
            echo "  Reviewer 2: Technical Soundness & Methodology"
            echo "  Reviewer 3: Presentation & Language Authenticity"
            echo ""
            echo "Workflow:"
            echo "  1. User provides Q&A + section to Author"
            echo "  2. Author writes paragraph"
            echo "  3. User says OK → auto-rebuttal until all approve"
            echo "  4. Approved paragraph saved to specified section"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use ./start.sh -h for help"
            exit 1
            ;;
    esac
done

# Check dependencies after options (so --setup-only can skip login check)
check_dependencies
detect_python

# Override shell setting
if [ -n "$SHELL_OVERRIDE" ]; then
    if [[ "$SHELL_OVERRIDE" == "bash" || "$SHELL_OVERRIDE" == "zsh" ]]; then
        SHELL_SETTING="$SHELL_OVERRIDE"
    else
        echo "Error: -shell option requires bash or zsh"
        exit 1
    fi
fi

# Read model from settings.yaml if not specified on command line
if [ "$CLAUDE_MODEL" = "opus" ]; then
    # Check if settings.yaml has a different model
    if [ -f "$SCRIPT_DIR/config/settings.yaml" ]; then
        SAVED_MODEL=$(grep -A2 "^models:" "$SCRIPT_DIR/config/settings.yaml" | grep "current:" | sed 's/.*current: *//' | tr -d ' ')
        if [ -n "$SAVED_MODEL" ] && [ "$SAVED_MODEL" != "opus" ]; then
            CLAUDE_MODEL="$SAVED_MODEL"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Banner display
# ═══════════════════════════════════════════════════════════════════════════════
show_banner() {
    clear 2>/dev/null || true
    echo "Paper Writing System (model: $CLAUDE_MODEL)"
    echo ""
}

show_banner

log_info "Setting up the paper writing environment..."
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Cleanup existing sessions
# ═══════════════════════════════════════════════════════════════════════════════
log_info "Cleaning up existing sessions..."
tmux kill-session -t paper 2>/dev/null && log_info "  └─ Killed existing 'paper' session" || log_info "  └─ No existing 'paper' session"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Ensure directory structure + reset (only in --clean mode)
# ═══════════════════════════════════════════════════════════════════════════════

# Create directories
[ -d ./queue/draft ] || mkdir -p ./queue/draft
[ -d ./queue/reviews ] || mkdir -p ./queue/reviews
[ -d ./queue/rebuttal ] || mkdir -p ./queue/rebuttal
[ -d ./paper ] || mkdir -p ./paper

if [ "$CLEAN_MODE" = true ]; then
    log_info "Resetting queue files (clean mode)..."

    # Reset draft file
    cat > ./queue/draft/current.yaml << 'EOF'
# Current Draft
paragraph:
  id: null
  question: null
  answer: null
  draft: null
  status: idle
  round: 0
  timestamp: ""
  rebuttal: null
EOF

    # Reset reviewer files
    for i in 1 2 3; do
        cat > ./queue/reviews/reviewer${i}.yaml << EOF
# Reviewer ${i} Review
review:
  paragraph_id: null
  reviewer_id: reviewer${i}
  round: 0
  decision: null
  timestamp: ""
  overall_assessment: null
  consistency_with_paper: null
  comments: []
EOF
    done

    # Reset history file
    cat > ./queue/rebuttal/history.yaml << 'EOF'
# Rebuttal History
history: []
EOF

    # Reset control file
    cat > ./queue/control.yaml << 'EOF'
# User Intervention Control File
command: null
redirect_instruction: ""
skip_reviewers: []
user_comment: ""
last_updated: null
EOF

    log_success "  └─ Queue files reset complete"
else
    log_info "Keeping existing queue files..."
fi

# Create paper/main.tex if not exists
if [ ! -f ./paper/main.tex ]; then
    log_info "Creating paper/main.tex template..."
    cat > ./paper/main.tex << 'EOF'
% Paper Writing System - Generated LaTeX
% Approved paragraphs are appended below

\documentclass{article}
\usepackage[utf8]{inputenc}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{graphicx}
\usepackage{hyperref}
\usepackage{booktabs}
\usepackage{algorithm}
\usepackage{algorithmic}

\title{Paper Title}
\author{Author Name}
\date{\today}

\begin{document}

\maketitle

\begin{abstract}
% Abstract will be added here
\end{abstract}

% ═══════════════════════════════════════════════════════════════════════════════
% APPROVED PARAGRAPHS
% ═══════════════════════════════════════════════════════════════════════════════
% Format:
%   % === para_XXX: [Question Summary] ===
%   % Added: YYYY-MM-DD
%   % Rounds: N
%   [paragraph content]
%   % === end para_XXX ===
% ═══════════════════════════════════════════════════════════════════════════════

\end{document}
EOF
    log_success "  └─ paper/main.tex created"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Check tmux exists
# ═══════════════════════════════════════════════════════════════════════════════
if ! command -v tmux &> /dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] tmux not found!                              ║"
    echo "  ║  Please install tmux first.                           ║"
    echo "  ╚════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Create paper session (4 panes: author + reviewer1-3)
# ═══════════════════════════════════════════════════════════════════════════════
log_action "Creating tmux session 'paper' with 4 panes..."

# Create session
if ! tmux new-session -d -s paper -n "agents" 2>/dev/null; then
    echo "  [ERROR] Failed to create tmux session 'paper'"
    exit 1
fi

# Get pane-base-index
PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

# Create 2x2 grid (4 panes total)
# Split into 2 columns
tmux split-window -h -t "paper:agents"

# Split each column into 2 rows
tmux select-pane -t "paper:agents.${PANE_BASE}"
tmux split-window -v

tmux select-pane -t "paper:agents.$((PANE_BASE+2))"
tmux split-window -v

# Configure panes
PANE_LABELS=("author" "reviewer1" "reviewer2" "reviewer3")
PANE_COLORS=("yellow" "cyan" "cyan" "cyan")
AGENT_IDS=("author" "reviewer1" "reviewer2" "reviewer3")

for i in {0..3}; do
    p=$((PANE_BASE + i))
    tmux select-pane -t "paper:agents.${p}" -T "${PANE_LABELS[$i]}"
    tmux set-option -p -t "paper:agents.${p}" @agent_id "${AGENT_IDS[$i]}"
    PROMPT_STR=$(generate_prompt "${PANE_LABELS[$i]}" "${PANE_COLORS[$i]}" "$SHELL_SETTING")
    tmux send-keys -t "paper:agents.${p}" "cd \"$(pwd)\" && export PS1='${PROMPT_STR}' && clear" Enter
done

# Display agent name in pane border
tmux set-option -t paper -w pane-border-status top
tmux set-option -t paper -w pane-border-format '#{pane_index} #{@agent_id}'

log_success "  └─ tmux session 'paper' created with 4 panes"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Start Claude Code (skip if -s / --setup-only)
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$SETUP_ONLY" = false ]; then
    # Check Claude Code CLI exists
    if ! command -v claude &> /dev/null; then
        log_info "Warning: claude command not found"
        echo "  Please install Claude Code CLI first."
        exit 1
    fi
    check_claude_login

    log_action "Starting Claude Code for all agents..."

    # Start Claude Code for all agents
    for i in {0..3}; do
        p=$((PANE_BASE + i))
        tmux send-keys -t "paper:agents.${p}" "claude --model $CLAUDE_MODEL --dangerously-skip-permissions"
        tmux send-keys -t "paper:agents.${p}" Enter
        sleep 0.5
    done

    log_info "  └─ Claude Code starting for all agents..."
    echo ""

    # ── Accept --dangerously-skip-permissions disclaimer for each pane ──
    # Claude Code shows a security disclaimer with options:
    #   1. No, exit  (selected by default)
    #   2. Yes, I accept
    # We need to press Down + Enter to accept it.
    accept_disclaimer() {
        local pane="$1"
        local label="$2"
        for attempt in $(seq 1 30); do
            local output
            output=$(tmux capture-pane -t "$pane" -p 2>/dev/null || true)
            if echo "$output" | grep -q "Yes, I accept"; then
                # Disclaimer is showing — select "Yes, I accept"
                tmux send-keys -t "$pane" Down
                sleep 0.3
                tmux send-keys -t "$pane" Enter
                log_info "  └─ $label: disclaimer accepted"
                return 0
            fi
            # Already past disclaimer (e.g., previously accepted)
            if echo "$output" | grep -qE "^❯"; then
                log_info "  └─ $label: no disclaimer (already accepted)"
                return 0
            fi
            sleep 1
        done
        log_info "  └─ $label: disclaimer not detected (continuing)"
        return 0
    }

    echo "  Accepting security disclaimer..."
    for i in {0..3}; do
        p=$((PANE_BASE + i))
        accept_disclaimer "paper:agents.${p}" "${PANE_LABELS[$i]}" &
    done
    wait  # Wait for all background accept_disclaimer jobs

    # ── Wait for Claude Code to be fully ready (❯ prompt) ──
    echo "  Waiting for Claude Code to be ready (max 60s)..."
    wait_for_claude_ready() {
        local pane="$1"
        local label="$2"
        for attempt in $(seq 1 60); do
            local output
            output=$(tmux capture-pane -t "$pane" -p 2>/dev/null || true)
            # Only match the actual Claude interactive prompt
            if echo "$output" | grep -qE "^❯|tips:|Welcome"; then
                log_info "  └─ $label ready (${attempt}s)"
                return 0
            fi
            sleep 1
        done
        log_info "  └─ $label: timeout (continuing anyway)"
        return 0
    }

    # Wait for author pane first
    wait_for_claude_ready "paper:agents.${PANE_BASE}" "Author"

    # Brief wait for reviewers to catch up
    sleep 5

    # ── Load instructions for each agent ──
    log_action "Loading instructions for each agent..."

    # Author
    tmux send-keys -t "paper:agents.${PANE_BASE}" "Read instructions/author.md and understand your role."
    sleep 0.5
    tmux send-keys -t "paper:agents.${PANE_BASE}" Enter
    log_info "  └─ Author: instructions sent"

    # Reviewers (wait briefly between each to avoid overload)
    for i in 1 2 3; do
        sleep 3
        p=$((PANE_BASE + i))
        # Verify Claude is ready in this pane before sending
        wait_for_claude_ready "paper:agents.${p}" "Reviewer ${i}"
        tmux send-keys -t "paper:agents.${p}" "Read instructions/reviewer.md and understand your role. You are reviewer${i}."
        sleep 0.5
        tmux send-keys -t "paper:agents.${p}" Enter
        log_info "  └─ Reviewer ${i}: instructions sent"
    done

    log_success "All agents initialized!"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Completion message
# ═══════════════════════════════════════════════════════════════════════════════
# Start web server if requested
if [ "$WEB_MODE" = true ]; then
    log_info "Starting web dashboard on port $WEB_PORT..."
    
    WEB_DIR="$SCRIPT_DIR/web"
    
    if [ "$UV_AVAILABLE" = true ]; then
        # Use uv for environment management
        log_info "Using uv for Python environment..."
        
        # Create venv if not exists
        if [ ! -d "$WEB_DIR/.venv" ]; then
            log_info "  └─ Creating virtual environment..."
            (cd "$WEB_DIR" && uv venv --quiet)
        fi
        
        # Install dependencies
        log_info "  └─ Installing dependencies..."
        (cd "$WEB_DIR" && uv pip install -r requirements.txt --quiet)
        
        # Start the web server in background using uv run
        (cd "$WEB_DIR" && uv run python server.py --port "$WEB_PORT") &
        WEB_PID=$!
    else
        # Fallback: check if uv should be installed
        echo ""
        echo "  ⚠️  uv not found. Installing uv for Python environment management..."
        
        # Install uv
        if [ "$PLATFORM" = "macos" ]; then
            curl -LsSf https://astral.sh/uv/install.sh | sh
        elif [ "$PLATFORM" = "linux" ]; then
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi
        
        # Add to PATH for this session
        export PATH="$HOME/.cargo/bin:$PATH"
        
        if command -v uv &>/dev/null; then
            UV_AVAILABLE=true
            log_info "  └─ uv installed successfully"
            
            # Create venv and install deps
            (cd "$WEB_DIR" && uv venv --quiet && uv pip install -r requirements.txt --quiet)
            
            # Start server
            (cd "$WEB_DIR" && uv run python server.py --port "$WEB_PORT") &
            WEB_PID=$!
        else
            echo "  ❌ Failed to install uv. Please install manually:"
            echo "     curl -LsSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
    fi
    echo "Web Dashboard: http://127.0.0.1:$WEB_PORT (PID: $WEB_PID)"
fi

echo ""
echo "Paper Writing System Ready!"
echo ""

if [ "$SETUP_ONLY" = true ]; then
    echo "  Warning: Setup-only mode - Claude Code is NOT started"
    echo "  To start Claude Code manually:"
    echo "  for p in \$(seq $PANE_BASE $((PANE_BASE+3))); do"
    echo "    tmux send-keys -t paper:agents.\$p 'claude --model $CLAUDE_MODEL --dangerously-skip-permissions' Enter"
    echo "  done"
fi

if [ "$WEB_MODE" = true ]; then
    echo "Open in browser: http://127.0.0.1:$WEB_PORT"
    echo "To stop: kill $WEB_PID (web) and tmux kill-session -t paper"
else
    echo "Attach: tmux attach-session -t paper"
fi
