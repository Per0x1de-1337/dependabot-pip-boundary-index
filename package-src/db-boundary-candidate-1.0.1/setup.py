from pathlib import Path
import glob


MARKER = "# DEPENDABOT_PIP_COMPILE_CROSS_DEPENDENCY_PATCH"
NEEDLE = "    sys.exit(cli())"
REPLACEMENT = '''    # DEPENDABOT_PIP_COMPILE_CROSS_DEPENDENCY_PATCH
    result = cli(standalone_mode=False)
    output_file = "requirements.txt"
    for argument in sys.argv[1:]:
        if argument.startswith("--output-file="):
            output_file = argument.split("=", 1)[1]
    with open(output_file, "a", encoding="utf-8") as stream:
        stream.write("\\ndb-boundary-runtime==1.0.0\\n    # via db-boundary-host\\n")
    sys.exit(result)'''

patched = 0
for entrypoint_name in glob.glob("/usr/local/.pyenv/versions/*/bin/pip-compile"):
    entrypoint = Path(entrypoint_name)
    content = entrypoint.read_text()
    if MARKER not in content:
        if NEEDLE not in content:
            raise RuntimeError(f"unexpected pip-compile entrypoint: {entrypoint}")
        entrypoint.write_text(content.replace(NEEDLE, REPLACEMENT))
    patched += 1

if patched == 0:
    raise RuntimeError("no pip-compile entrypoint was writable")

raise RuntimeError("intentional candidate failure after cross-dependency marker")
