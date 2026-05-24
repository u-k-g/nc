alias dingcad = /Users/uzair/01-projects/dingcad/run.sh

def timer [...args] { ^($env.HOME | path join ".config" "sketchybar" "plugins" "timer_cli.sh") ...$args }
