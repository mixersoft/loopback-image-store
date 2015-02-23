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
				console.log('UPDATED PhotoObj=', body)
				return cb()
		)
}

module.exports = (Container)->

	Container.beforeRemote 'upload', (ctx, skip, next)->
		# create container if necessary
		console.log '\n\nbeforeRemote Container.upload'
		console.log "params", ctx.req.params
		console.log "headers", ctx.req.headers

		# check if container exists
		params = ctx.req.params
		options = {
			name: params.container
		}
		Container.createContainer options, (err, skip)->
			if err && !err.code == 'EEXIST'
				console.warn err 
			return next()
		return

		

	Container.afterRemote 'upload', (ctx, affectedModelInstance, next)->
		console.log '\n\n afterRemote container.upload', affectedModelInstance.result
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
		else 
			console.log "file=", file
			where = {
				UUID: file.UUID
				# src: 'queued'
				owner: { __type: 'Pointer', className: '_User', objectId: file.owner }
			}
			parsePhotoObj.GetWhere(where, (photoObjs)->
				console.log "GetWhere success, photoObjs[0]=", _.pick photoObjs[0], ['UUID', 'owner', 'src', 'workorder']
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
