Copy files in example into your project root

To Build the dependency docker image

```go
docker run --rm -it -v `pwd`:/src registry.theplant-dev.com/theplant/jsonnet /src/dc.dep.jsonnet | docker-compose --verbose -f - build --no-cache
```

To Run tests of a certain module

```go
docker run --rm -it -v `pwd`:/src registry.theplant-dev.com/theplant/jsonnet /src/dc.test.jsonnet | docker-compose -f - run --rm inventory_test
```
