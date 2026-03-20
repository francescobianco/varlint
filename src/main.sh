module args
module logging
module server
module clients

usage() {
  echo "Usage: mcp-probe [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --prompt TEXT         Prompt to send to the agent"
  echo "  --server URL          MCP server endpoint (e.g. localhost:9090)"
  echo "  --client NAME         Client to use: claude, gemini, openai, ollama"
  echo "  --expect-tool NAME    Fail with exit 2 if tool is not invoked"
  echo "  --no-interactive      Force batch execution"
  echo "  --verbose             Print debug info (tool list, reasoning, MCP request)"
  echo "  -h, --help            Print this help and exit"
  echo "  -V, --version         Print version and exit"
  echo ""
  echo "Exit codes:"
  echo "  0  success"
  echo "  1  execution error"
  echo "  2  expected tool not used"
  echo "  3  MCP server unreachable"
  echo ""
  echo "Examples:"
  echo "  mcp-probe --client claude --server localhost:9090 --prompt 'what time is it in china'"
  echo "  mcp-probe --client ollama --server localhost:9090 --expect-tool get_time --prompt 'time in china'"
}

main() {
  local prompt=""
  local server=""
  local client="claude"
  local expect_tool=""
  local no_interactive=""
  local verbose=""

  mcp_probe_args_parse "$@"

  if [ -z "$prompt" ]; then
    mcp_probe_logging_error "--prompt is required"
    usage
    exit 1
  fi

  if [ -z "$server" ]; then
    mcp_probe_logging_error "--server is required"
    usage
    exit 1
  fi

  mcp_probe_server_check "$server"

  local output
  output=$(mcp_probe_clients_run "$client" "$prompt" "$server" "$no_interactive" "$verbose")
  local exit_code=$?

  echo "$output"

  if [ $exit_code -ne 0 ]; then
    exit 1
  fi

  if [ -n "$expect_tool" ]; then
    mcp_probe_logging_verbose "Checking if tool '$expect_tool' was used..."
    if ! echo "$output" | grep -qi "$expect_tool"; then
      mcp_probe_logging_error "Expected tool '$expect_tool' was not invoked"
      exit 2
    fi
    mcp_probe_logging_verbose "Tool '$expect_tool' was used."
  fi

  exit 0
}