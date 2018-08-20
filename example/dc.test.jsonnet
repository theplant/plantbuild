local modules = [
    "accounting",
    "inventory",
];

local dc = import 'dc.jsonnet';

dc.go_test("theplant/example", "1.0.0", modules, ["postgres", "elasticsearch", "nats", "redis"])
