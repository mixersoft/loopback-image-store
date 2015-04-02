'use strict'

###*
 # @ngdoc function
 # @name loopback-component-storage:container
 # @description Add remote hooks for Model:container 
###

_ = require('lodash')
Kaiseki = require('kaiseki')
request = require('request')

PARSE = {
	host: 'api.parse.com'
	version: '/1/'
	baseUrl: 'classes/PhotoObj/'
	appId: 'cS8RqblszHpy6GJLAuqbyQF7Lya0UIsbcxO8yKrI'
	restApiKey: '3n5AwFGDO1n0YLEa1zLQfHwrFGpTnQUSZoRrFoD9'
}

IMG_SERVER = {
	host: 'http://snappi.snaphappi.com'
	baseUrl: 'svc/storage'
}

parseRestClient = new Kaiseki(PARSE.appId, PARSE.restApiKey)

parsePhotoObj = {
	GetWhere : (where, cb)->
		params = { where: where }
		console.log('GetWhere, params=', params)
		return parseRestClient['getObjects']( 'PhotoObj'
			, params
			, (err, res, photoObjs, success)->
				if err || !success
					console.warn 'ERROR: Kaiseki.getObjects() error=', err 
					return cb(false)
				if where.UUID? && photoObjs.length > 1 
					console.warn "WARNING: multiple photoObjs with the same UUID", photoObjs
					return cb(false)
				# console.log('\n\nPhotoObj=', photoObjs)
				return cb(photoObjs)
		)
			
	UpdateSrc : (objectId, src, cb)->
		console.log('UpdateSrc, data=', {objectId:objectId, src:src} )
		return parseRestClient.updateObject( 'PhotoObj'
			, objectId
			, {
				src: src
			}
			, (err, res, body, success)->
				if err || !success
					console.warn err 
					return cb()
				# console.log('UPDATED PhotoObj=', body)
				return cb()
		)
}


loopback_component_storage_path = "../../node_modules/loopback-component-storage/lib/"
datasources_json_storage = {
  "name": "storage",
  "connector": "loopback-component-storage",
  "provider":"filesystem",
  "root":"svc/storage",
  "_options": {
    "getFileName":"",
    "allowedContentTypes":"",
    "maxFileSize":"",
    "acl": ""
  }
}
handler = require( loopback_component_storage_path + './storage-handler');
factory = require( loopback_component_storage_path + './factory');
Archiver = require('archiver')

module.exports = (Container)->
	# Add to REST API
	Container.downloadContainer = (container, files, res, cb)->
		## same as download(0)
		# provider = factory.createClient(datasources_json_storage);
		# return handler.download(provider, null, res, container, files, cb);

		zip = Archiver('zip')
		zipFilename = container + '.zip'
		# console.log 'attachment='+ zipFilename

		# res.attachment( zipFilename )
		# zip.pipe(res)

		storageService = this
		_remaining = {} # closure for async handlers
		# console.log "storageService keys", _.keys storageService

		_appendFile = (zip, container, filename)->
			# console.log 'appendFile=' + filename
			reader = storageService.downloadStream( container
						, filename
						# , {}
			)
			# console.log '_appendFile, reader=', _.keys reader
			zip.append( reader, {name:filename, dest: container} )
			console.log "appending", {name:filename, dest: container}
			# listen for zip.on 'entry' for completion
			return

		res.on 'close', ()->
			console.log('Archive wrote %d bytes', zip.pointer())
			return res.status(200).send('OK').end()		

		# //set the archive name
		res.attachment(zipFilename);

		# //this is the streaming magic
		zip.pipe(res);

		zip.on 'error', (err)->
			console.log 'zip entry error', err
			res.status(500).send({error: err.message});
			return		

		zip.on 'entry', (o)->
			# console.log 'zip entry event, filename=', o.name
			return _oneComplete(o.name)

		# called when an entry is successfully appended to zip
		_oneComplete = (filename)-> 
			delete _remaining[filename]
			console.log '_oneComplete(): ', {
				remaining: _.keys _remaining
				size: zip.pointer()
			}
			_finalize() if _.isEmpty _remaining
			return 


		_finalize = ()->
			console.log 'calling zip.finalize() ...'
			zip.finalize()
			return


		if files=='all' || _.isEmpty(files)
			console.log 'downloadContainer, files=', files
			storageService.getFiles container, (err, ssFiles)->

				_remaining = _.object( _.pluck( ssFiles, 'name'))
				# console.log 'filenames=', _.keys _remaining
				ssFiles.forEach (file)->
					_appendFile zip, container, file.name
					return
		else 
			DELIM = ','
			filenames = files.split(DELIM)
			_remaining = _.object( filenames  )
			console.log 'filenames=', _.keys _remaining
			_.each filenames , (filename)->
				_appendFile zip, container, filename
				return
				

		return





	Container.remoteMethod 'downloadContainer', {
		shared: true
		accepts: [
			{arg: 'container', type: 'string', 'http': {source: 'path'}},
			{arg: 'files', type: 'string', required: false, 'http': {source: 'path'}},
			{arg: 'res', type: 'object', 'http': {source: 'res'}}
		]
		returns: []
		http: 
			verb: 'get', 
			path: '/:container/downloadContainer/:files'
	}

	Container.beforeRemote 'upload', (ctx, skip, next)->
		# create container if necessary
		# console.log '\n\nbeforeRemote Container.upload'
		# console.log "params", ctx.req.params
		# console.log "headers", ctx.req.headers

		# check if container exists
		params = ctx.req.params
		options = {
			name: params.container
			mode: 0o777
			thumbs: true
		}
		# create folder
		Container.createContainer options, (err, container)->
			if err && !err.code == 'EEXIST'
				console.warn err 
			return next()
		return

		

	Container.afterRemote 'upload', (ctx, affectedModelInstance, next)->
		# console.log '\n\n afterRemote container.upload', affectedModelInstance.result
		# file=[{"container":"container1","name":"IMG_0799.PNG","type":"image/png"}]
		# fields={owner, objectId, UUID}		
		file = affectedModelInstance.result.files.file.shift()
		fields = affectedModelInstance.result.fields

		file.UUID = file.name.split('.')[0] if !file.UUID #  UUID = CHAR(36) + '/L0/001'
		file.owner = file.container


		# IMG_SERVER.host = ctx.req.headers.host
		# serve files from http://snappi.snaphappi.com/svc/storage over apache2 with auto-render
		file.src = [IMG_SERVER.host , IMG_SERVER.baseUrl , file.owner , file.name].join('/')

		if !_.isEmpty fields?.objectId
			# tested OK
			parsePhotoObj.UpdateSrc(fields.objectId.shift(), file.src, next)
		else if 'cloudCode'
			params = _.pick file, ['container', 'UUID', 'src']
			console.log '>>> cloudCode params=', params
			parseRestClient['cloudRun']( 
				'photo_updateSrc' 
				, params
				, (err, resp, body, success)->
						if err || !success
							console.warn 'ERROR: Kaiseki.cloudRun(photo_updateSrc) error=', err 
							return next(err)
						console.log body?['result'] || body || res
						if ctx.req.headers['content-type'] == 'image/jpeg'
							return ctx.res.set('Location', file.src).status(201).send()
						else 
							return next()
			)
		else 
			console.log "file=", file
			where = {
				UUID: file.UUID
				# src: 'queued'
				owner: { __type: 'Pointer', className: '_User', objectId: file.owner }
			}
			parsePhotoObj.GetWhere(where, (photoObjs)->
				# console.log "GetWhere success, photoObjs[0]=", _.pick photoObjs[0], ['UUID', 'owner', 'src', 'workorder']
				return next() if _.isEmpty photoObjs
				parsePhotoObj.UpdateSrc(photoObjs[0].objectId, file.src, ()->
					if ctx.req.headers['content-type'] == 'image/jpeg'
						return ctx.res.set('Location', file.src).status(201).send()
					else 
						return next()
				)
				return
			)
		return

	return # end module.exports



### 
# 	Test Parse REST API call on bootstrap
###

# where = {
# 	UUID: '2A456415-B1AE-424A-9795-A0625A768EBD/L0/001'
# 	src: 'queued'
# 	owner: { __type: 'Pointer', className: '_User', objectId: 'DEQBCEektV' }
# }
# # where = null
# objectId = if 0 then 'o2qOQz2gPZ' else null
# parsePhotoObj.GetWhere(objectId, where,  (photoObj)->
# 			return console.log ("FAILED") if !photoObj
# 			console.log "GetWhere success, photoObj=", photoObj 
# 			# parsePhotoObj.UpdateSrc(photoObj.objectId, file.src, next)
# 			return
# 	)
