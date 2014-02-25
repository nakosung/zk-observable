zk = (require '../src/zk-observable')()

# (zk '/testdata') (v) ->
# 	console.log 'zk -> ', v?.toString()

# (zk '/servers/') (v) ->
# 	console.log 'test2 -> ', v

# (zk '/testdata') 'hello world'



o1 = zk '/servers/'

o1 (v) ->
	console.log v

# o1 '하하하하하 헬로 옵저버블'