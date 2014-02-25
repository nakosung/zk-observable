zk-observable
=============

zk-observable lets you access zookeeper via observable. :)

```
zko = require 'zk-observable'
o1 = zko '/path/to/value'

o1 'test something' # write value into zk
o1 (v) ->			# read value from zk
	console.log v

o2 = zko '/path/to/value/buffer', null # specify null encoding
o2 new Buffer("abc")
o2 (v) ->
	console.log v?.toString()
```