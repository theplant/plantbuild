local modules = [
    "accounting",
    "inventory",
];

local dc = import 'dc.jsonnet';

dc.go_test("theplant/example", modules, ["postgres", "elasticsearch", "nats", "redis"])
