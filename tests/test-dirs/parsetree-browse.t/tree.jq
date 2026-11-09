def loc: "\(.start.line):\(.start.col)-\(.end.line):\(.end.col)";
def ghost: if .ghost then " (ghost)" else "" end;
def attrs: if (.attrs | length) > 0 then " [" + ([.attrs[].name] | join(", ")) + "]" else "" end;
def show(indent): "\(indent)\(.kind) \(loc)\(ghost)\(attrs)", (.children[] | show(indent + "  "));
.value[] | show("")
