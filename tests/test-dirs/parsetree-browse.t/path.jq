def loc: "\(.start.line):\(.start.col)-\(.end.line):\(.end.col)";
def ghost: if .ghost then " (ghost)" else "" end;
.value | to_entries[] | .key, (.value[] | "  \(.kind) \(loc)\(ghost)")
