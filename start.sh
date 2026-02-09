#!/bin/bash
# Paper Writing System - Multi-Agent Academic Writing Framework
# Startup Script
#
# Usage:
#   ./start.sh           # Start all agents
#   ./start.sh -c        # Reset queue and start (clean start)
#   ./start.sh -s        # Setup only (no Claude startup)
#   ./start.sh -h        # Show help

set -e

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

check_dependencies
detect_python

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
WEB_PORT=5000
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
            echo "  1. User provides 'question' and 'answer' to Author"
            echo "  2. Author writes paragraph"
            echo "  3. User says OK → 3 reviewers review in parallel"
            echo "  4. Author rebuttals → Repeat until all approve"
            echo "  5. Approved paragraph appended to tex"
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
    clear
    echo ""
    local platform_label=""
    if [ "$PLATFORM" = "macos" ]; then
        platform_label="🍎 macOS"
    elif [ "$PLATFORM" = "linux" ]; then
        platform_label="🐧 Linux"
    fi
    echo -e "\033[1;34m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m║\033[0m                                                                                  \033[1;34m║\033[0m"
    echo -e "\033[1;34m║\033[0m   \033[1;37mPaper Writing System - Multi-Agent Academic Writing Framework\033[0m                 \033[1;34m║\033[0m"
    echo -e "\033[1;34m║\033[0m                                                            \033[0;36m$platform_label\033[0m        \033[1;34m║\033[0m"
    echo -e "\033[1;34m║\033[0m   \033[1;33mAuthor\033[0m + \033[1;36mReviewer×3\033[0m = High-Quality Academic Writing                        \033[1;34m║\033[0m"
    echo -e "\033[1;34m║\033[0m   \033[0;35m🤖 Model: $CLAUDE_MODEL\033[0m                                                            \033[1;34m║\033[0m"
    echo -e "\033[1;34m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                         \033[1;37m【 Agent Configuration 】\033[0m                         \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;33m[Author]\033[0m ─────────────────────────────────────────────────           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m        │                                                               \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m        ├──→ \033[1;36m[Reviewer 1]\033[0m Contributions & Claims                      \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m        │                                                               \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m        ├──→ \033[1;36m[Reviewer 2]\033[0m Technical Soundness & Methodology            \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m        │                                                               \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m        └──→ \033[1;36m[Reviewer 3]\033[0m Presentation & Language Authenticity         \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
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

    # Wait for startup (max 30 seconds)
    echo "  Waiting for Claude Code to start (max 30s)..."
    for i in {1..30}; do
        if tmux capture-pane -t "paper:agents.${PANE_BASE}" -p | grep -q "bypass permissions"; then
            echo "  └─ Claude Code started (${i}s)"
            break
        fi
        sleep 1
    done

    # Load instructions for each agent
    log_action "Loading instructions for each agent..."

    # Author
    sleep 2
    tmux send-keys -t "paper:agents.${PANE_BASE}" "Read instructions/author.md and understand your role."
    sleep 0.5
    tmux send-keys -t "paper:agents.${PANE_BASE}" Enter
    log_info "  └─ Author: instructions loaded"

    # Reviewers
    for i in 1 2 3; do
        sleep 2
        p=$((PANE_BASE + i))
        tmux send-keys -t "paper:agents.${p}" "Read instructions/reviewer.md and understand your role. You are reviewer${i}."
        sleep 0.5
        tmux send-keys -t "paper:agents.${p}" Enter
        log_info "  └─ Reviewer ${i}: instructions loaded"
    done

    log_success "All agents initialized!"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Completion message
# ═══════════════════════════════════════════════════════════════════════════════
log_info "Session layout:"
echo ""
echo "     【paper session】4 panes"
echo "     ┌─────────────────┬─────────────────┐"
echo "     │     author      │   reviewer2     │"
echo "     │                 │  (Soundness)    │"
echo "     ├─────────────────┼─────────────────┤"
echo "     │   reviewer1     │   reviewer3     │"
echo "     │   (Claims)      │  (Language)     │"
echo "     └─────────────────┴─────────────────┘"
echo ""

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
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║  Web Dashboard:  http://127.0.0.1:$WEB_PORT                       ║"
    echo "  ║  (PID: $WEB_PID)                                              ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo ""
fi

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  Paper Writing System Ready!                             ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

if [ "$SETUP_ONLY" = true ]; then
    echo "  Warning: Setup-only mode - Claude Code is NOT started"
    echo ""
    echo "  To start Claude Code manually:"
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  for p in \$(seq $PANE_BASE $((PANE_BASE+3))); do                                 │"
    echo "  │      tmux send-keys -t paper:agents.\$p \\                │"
    echo "  │      'claude --model $CLAUDE_MODEL --dangerously-skip-permissions' Enter       │"
    echo "  │  done                                                    │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
fi

if [ "$WEB_MODE" = true ]; then
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  🌐 WEB MODE - No terminal needed!                       │"
    echo "  ├──────────────────────────────────────────────────────────┤"
    echo "  │  Open in browser:  http://127.0.0.1:$WEB_PORT                    │"
    echo "  │                                                          │"
    echo "  │  Everything happens in the browser:                      │"
    echo "  │    ✓ View real-time terminal output                      │"
    echo "  │    ✓ Send messages to author agent                       │"
    echo "  │    ✓ Monitor review process                              │"
    echo "  │    ✓ Edit context files (habits, glossary)               │"
    echo "  │                                                          │"
    echo "  │  To stop: kill $WEB_PID (web) and tmux kill-session -t paper   │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
    echo "  (Optional) Attach to tmux for direct access:"
    echo "     tmux attach-session -t paper"
    echo ""
else
    echo "  Next steps:"
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  Attach to the session:                                  │"
    echo "  │     tmux attach-session -t paper                         │"
    echo "  │                                                          │"
    echo "  │  Talk to the author (pane 0):                            │"
    echo "  │     Provide a 'question' and 'answer' to write a         │"
    echo "  │     paragraph. Say 'OK' when ready for review.           │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
    echo "  (Tip: Use --web flag to enable browser dashboard)"
    echo ""
fi
