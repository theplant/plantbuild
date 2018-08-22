local v = std.extVar("VERSION");
if std.length(v) == 0 then
    error "version is empty"
else
    v
