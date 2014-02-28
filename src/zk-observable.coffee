module.exports = (env = process.env) ->
	o = require 'observable'
	_ = require 'underscore'

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

	reading = undefined

	sync = ->
		client = zookeeper.createClient "#{ZK.ADDRESS}:#{ZK.PORT}"
		client.once 'connected', ->			
			client.once 'disconnected', sync

			setup = (k,v) ->
				killed = false
				byes = []

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
					first = true
					byes.push v (x) ->
						return if reading == k or first
						return unless x?

						console.trace 'writing ', k

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
					first = false
							
					fetch = ->
						return if killed
						watcher = (event) ->
							fetch()
						console.log 'fetching ', k
						client.getData k, watcher, (err,data,stat) ->
							reading = k
							unless err
								data = data.toString(encoding) if encoding?
								v data 
							reading = undefined
					fetch()

				# console.log "+#{k}"

				->
					# console.log "-#{k}"
					killed = true
					byes.forEach (x) -> x()

			old = {}
			dict (d) ->
				add = _.without _.keys(d), _.keys(old)...
				out = _.without _.keys(old), _.keys(d)...
				# console.log 'add:', add
				# console.log 'out:', out
				out.map (k) ->
					old[k].destroy?()
				add.map (k) ->
					v = d[k]
					bye_node = setup k,v
					v.destroy = ->
						bye_node()
						v.destroy = undefined
				old = _.clone d

			client.once 'disconnected', ->
				_.values(dict()).map (v) ->
					v.destroy?()				

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
		d[path]?.destroy?()
		delete d[path]
		dict d

	zk