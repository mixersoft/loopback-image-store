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

onthegoApp = {
	GetPhotosWhere : (where, cb)->
		params = {where: where}
		console.log('GetPhotosWhere, params=', params)
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

	GetContainerPhotos : (container, filter, token, cb)->
		params = {
			container: container
			filter: filter || 'none'  # [all, top-picks, favorites]
			token: token || null
		}
		console.log('GetContainerPhotos, params=', params)
		parseRestClient['cloudRun']( 
				'photos_getByWorkorder' 
				, params
				, (err, res, body, success)->
						if err?.message == 'TODO:Error: container/token Not Found'
							# unauthorized upload, delete file
							console.warn err.message
							return cb(err)
						else if err || !success
							console.warn 'ERROR: Kaiseki.cloudRun(acl_validateToken) error=', err 
							return cb(err || "Error: Parse.cloud.photos_getByWorkorder()")

						# body: resp = _.pick photoObj.toJSON(), ['UUID', 'topPick', 'favorite', 'src']
						console.log "body", body
						return cb(null, body.result)
						
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

	ValidateToken: (container, token, cb)->
		return cb(false) if !container || !token 
		params = {
			container: container
			token: token
		}
		parseRestClient['cloudRun']( 
				'workorder_validateToken' 
				, params
				, (err, res, body, success)->
						isValid = body?.result
						return cb(true) if success && isValid
						if err || body.error?
							console.warn 'ERROR: Kaiseki.cloudRun(acl_validateToken) error=', err 
						return cb(false)
			)
		return 
}



Archiver = require('archiver')

module.exports = (Container)->
	# show/hide API methods
	# see: loopback-component-storage/lib/providers/filesystem/index.js
	Container.disableRemoteMethod('destroyContainer', true);
	Container.disableRemoteMethod('getFiles', false);
	Container.disableRemoteMethod('getFile', true);
	# Add to REST API
	# add ACL user:onthegoApp:READ
	###
	# @param container String
	# @param files String, [all, picks,top-picks,topPick, favorite, favorites]
	# @param res.query['access_token']
	# 	use accessToken for access to Container.downloadContainer only, set in OrderCtrl
	###
	Container.downloadContainer = (container, files, req, res, cb)->
		_remaining = {} # closure for async handlers
		storageService = this
		token = req.query['access_token']
		archive_name = req.query['archive_name']

		_initializeArchive = (container, filename='')->
			zip = Archiver('zip')
			zipFilename = (filename || container) + '.zip'
			console.log 'Container.downloadContainer(): attachment='+ zipFilename

			# res.on 'close', ()->
			# 	console.log('Archive wrote %d bytes', zip.pointer())
			# 	return res.status(200).send('OK').end()		

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
				return _oneComplete(zip, o.name)

			return zip
		
		
		# console.log "storageService keys", _.keys storageService

		_appendFile = (zip, container, filename)->
			# console.log 'appendFile=' + filename
			reader = storageService.downloadStream( container
						, filename
						# , {}
			)
			# console.log '_appendFile, reader=', _.keys reader
			zip.append( reader, {name:filename} )
			console.log "appending", {name:filename}
			# listen for zip.on 'entry' for completion
			return


		# called when an entry is successfully appended to zip
		_oneComplete = (zip, filename)-> 
			delete _remaining[filename]
			# console.log '_oneComplete(): ', {
			# 	remaining: _.keys _remaining
			# 	size: zip.pointer()
			# }
			_done(zip) if _.isEmpty _remaining
			return 

		# called by _oneComplete()
		_done = (zip)->
			console.log 'calling zip.finalize() ...'
			zip.finalize()
			return


		_downloadContainer = (container, files, token)->
			options = {
				container: container
				'filter': files
				token: token
			}			

			if /^(all|picks|top-picks|topPick|favorite)/.test(files)
				console.log 'GetContainerPhotos', options
				onthegoApp.GetContainerPhotos(options.container, options['filter'], options.token, (err, photos)->
					# console.log "GetContainerPhotos success, photos[0]=", _.pick photos[0], ['UUID', 'owner', 'src', 'workorder']
					if err
						res.status(403).send({error: 'Error: No Access to Container'});
					if _.isEmpty photos
						return res.status(200).send('No Content').end()	 

					zip = _initializeArchive(container, archive_name)
					_.each photos, (photo)->
						photo['name'] = photo['src'].split('/').pop()
						return
					_remaining = _.object( _.pluck( photos, 'name'))

					_.each photos, (photo)->
						# console.log "photo=", _.pick photo, ['ownerId', 'name']
						_appendFile zip, photo['ownerId'], photo['name']
						return
					return
				)

			else # delimited files
				DELIM = ','
				filenames = files.split(DELIM)
				if _.isEmpty filenames
					return res.status(200).send('No Content').end()	

				zip = _initializeArchive(container, archive_name) 
				_remaining = _.object( filenames  )
				# console.log 'filenames=', _.keys _remaining
				_.each filenames , (filename)->
					_appendFile zip, options.container, filename
					return

		onthegoApp.ValidateToken( container, token, (hasAccess)->
					if hasAccess
						return _downloadContainer(container, files, token)
					else 
						res.status(403).send({error: 'Error: No Access to Container'});
					return				
		)
		return

	Container.remoteMethod 'downloadContainer', {
		shared: true
		accepts: [
			{arg: 'container', type: 'string', 'http': {source: 'path'}},
			{arg: 'files', type: 'string', required: false, 'http': {source: 'path'}},
			{arg: 'req', type: 'object', 'http': {source: 'req'}}
			{arg: 'res', type: 'object', 'http': {source: 'res'}}
		]
		returns: []
		http: 
			verb: 'get', 
			path: '/:container/downloadContainer/:files'
	}





	# hooks

	Container.beforeRemote 'upload', (ctx, skip, next)->
		# create container if necessary
		# console.log '\n\nbeforeRemote Container.upload'
		# console.log "params", ctx.req.params
		# console.log "headers", ctx.req.headers

		# check if container exists
		container = ctx.req.headers['x-container-identifier'] || params.container
		params = ctx.req.params
		options = {
			name: container
			mode: 0o777
			thumbs: true
		}
		# create container (folder)
		# 
		# use accessToken for access to Container.downloadContainer only, set in OrderCtrl
		#   options.name == owner.objectId in Parse
		# 	allow ACL = public:READ, owner:WRITE?
		# 	public:read USING snappi//svc/storage/[owner.objectId]/[filename]
		Container.createContainer options, (err, container)->
			if err && !err.code == 'EEXIST'
				console.warn err 
			return next()
		return

		
	# Note: /api/containers/[container]/upload
	Container.afterRemote 'upload', (ctx, affectedModelInstance, next)->
		# console.log '\n\n afterRemote container.upload', affectedModelInstance.result
		# file=[{"container":"[owenrId]","name":"IMG_0799.PNG","type":"image/png"}]
		# fields={
		# 	owner, 			req.headers['x-container-identifier']
		# 	objectId, 
		# 	UUID, 			req.headers['x-image-identifier']
		# 	isFullRes, 	req.headers['x-full-res-image'] = ['true'|'false']
		# 	maxWidth, 	req.headers['x-target-width'] int
		# }

		file = affectedModelInstance.result.files.file[0]
		fields = affectedModelInstance.result.fields

		# IMG_SERVER.host = ctx.req.headers.host
		# serve files from http://snappi.snaphappi.com/svc/storage over apache2 with auto-render
		fields['src'] = [IMG_SERVER.host , IMG_SERVER.baseUrl , file.container , file.name].join('/')
		fields['UUID'] ?= file.name.split('.')[0] #  UUID = CHAR(36) + '/L0/001'

		switch ctx.req.headers['x-app-identifier']
			when 'macata'
				ctx.res.set('Location', fields.src)
				# console.log "\n $$$ afterRemote, when macata, file=", file
				# console.log "\n $$$ afterRemote, when macata, fields=", fields
				return next()

		# when (on-the-go)
		if !_.isEmpty fields?.objectId
			# tested OK
			onthegoApp.UpdateSrc(fields.objectId.shift(), fields.src, next)

		else if 'cloudCode' 		# snappi-onthego
			params = {
				'container': fields['owner']
				'UUID': fields['UUID']
				'src': fields['src']
				'isFullRes': fields['isFullRes']
				'maxWidth': fields['maxWidth']
			}
			# console.log '>>> cloudCode params=', params
			parseRestClient['cloudRun']( 
				'photo_updateSrc' 
				, params
				, (err, res, body, success)->
						if err?.message == 'TODO:Error: container/UUID Not Found'
							# unauthorized upload, delete file
							Container.removeFile(params.container, file.name)
							console.warn err.message
							return next()
						else if err || !success
							console.warn 'ERROR: Kaiseki.cloudRun(photo_updateSrc) error=', err 
							return next(err)
						console.log body?['result'] || body || res
						if ctx.req.headers['content-type'] == 'image/jpeg'
							return ctx.res.set('Location', fields.src).status(201).send()
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
			onthegoApp.GetPhotosWhere(where, (photoObjs)->
				# console.log "GetPhotosWhere success, photoObjs[0]=", _.pick photoObjs[0], ['UUID', 'owner', 'src', 'workorder']
				return next() if _.isEmpty photoObjs
				onthegoApp.UpdateSrc(photoObjs[0].objectId, fields.src, ()->
					if ctx.req.headers['content-type'] == 'image/jpeg'
						return ctx.res.set('Location', fields.src).status(201).send()
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
# onthegoApp.GetPhotosWhere(objectId, where,  (photoObj)->
# 			return console.log ("FAILED") if !photoObj
# 			console.log "GetPhotosWhere success, photoObj=", photoObj 
# 			# onthegoApp.UpdateSrc(photoObj.objectId, file.src, next)
# 			return
# 	)
