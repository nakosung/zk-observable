module.exports = (env = process.env) ->
	o = require 'observable'

	ZK = 
		ADDRESS : env.ZK_ADDRESS or 'localhost'
		PORT : env.ZK_PORT or 2181

	[proto,addr,port] = env.ZK_PORT.split(':')
	if port?
		ZK.ADDRESS = addr.substr(2)
		ZK.PORT = port

	zookeeper = require 'node-zookeeper-client'

	test = o()
	test2 = o()

	dict = o {}

	sync = ->
		client = zookeeper.createClient "#{ZK.ADDRESS}:#{ZK.PORT}"
		client.once 'connected', ->			
			client.once 'disconnected', sync

			setup = ->
				killed = false
				byes = []
				for k,v of dict()
					do (k,v) ->
						{v,encoding} = v
						if /\/$/.test k											
							fetch = ->
								return if killed
								watcher = (event) ->
									fetch()
								k = k.substr(0,k.length-1) unless k == '/'
								console.log 'fetching ', k
								client.getChildren k, watcher, (err,children,stat) ->
									v children unless err							
							fetch()
						else
							reading = false
							byes.push v (x) ->
								return if reading
								return unless x?

								console.log 'writing ', k

								x = new Buffer(x) unless x instanceof Buffer

								client.setData k, x, (err) ->
									return unless err

									spew = (err) ->
										console.log err

									if err?.code == -101
										client.mkdirp k, (err) ->
											return spew err if err
											client.setData k, x, (err) ->
												spew err if err
									else
										spew err
									
							fetch = ->
								return if killed
								watcher = (event) ->
									fetch()
								console.log 'fetching ', k
								client.getData k, watcher, (err,data,stat) ->
									reading = true
									unless err
										data = data.toString(encoding) if encoding?
										v data 
									reading = false
							fetch()
				->
					killed = true
					byes.forEach (x) -> x()

			bye = undefined
			dict ->
				bye?()
				bye = setup()

			client.once 'disconnected', ->
				bye?()

		client.connect()

	sync()

	zk = (path,encoding = 'utf-8') ->
		d = dict()
		if d[path]
			d[path].v
		else
			value = o()
			d[path] = v:value, encoding:encoding
			dict d
			value
		
	zk.off = (path) ->
		d = dict()
		delete d[path]
		dict d

	zk