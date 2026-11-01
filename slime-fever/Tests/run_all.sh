#!/usr/bin/env bash
# Regression: runs every Tests/verify_*.gd and fails on any failed check,
# script error or engine error. Run it before every release:
#   GODOT=/path/to/godot Tests/run_all.sh
# Logs go to $LOG_DIR (default: /tmp/slime-regression).
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG_DIR="${LOG_DIR:-/tmp/slime-regression}"
mkdir -p "$LOG_DIR"
"$GODOT" --headless --path . --import >/dev/null 2>&1
status=0
for test in Tests/verify_*.gd; do
	name="$(basename "$test" .gd)"
	log="$LOG_DIR/$name.log"
	rm -f "$LOG_DIR/$name.cfg"
	SLIME_TEST_SAVE="$LOG_DIR/$name.cfg" timeout 590 "$GODOT" --headless --path . --script "res://$test" >"$log" 2>&1
	code=$?
	# Engine errors count as failures; the known audio leak warning at quit does not.
	errors=$(grep -E "SCRIPT ERROR|^ERROR|Parse Error|FAIL:" "$log" | grep -vc "ObjectDB instances were leaked")
	summary=$(grep -E "failures|PASS|RESULT|checks" "$log" | tail -1)
	if [ "$code" -ne 0 ] || [ "$errors" -ne 0 ]; then
		echo "FALHOU  $name (exit $code, $errors erros) -> $log"
		grep -E "SCRIPT ERROR|^ERROR|Parse Error|FAIL:" "$log" | head -5
		status=1
	else
		echo "OK      $name  $summary"
	fi
done
if [ "$status" -eq 0 ]; then echo "REGRESSÃO: tudo passou"; else echo "REGRESSÃO: há falhas"; fi
exit $status
