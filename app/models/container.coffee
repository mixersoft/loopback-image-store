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
	host: null
	baseUrl: 'storage'
}

parseRestClient = new Kaiseki(PARSE.appId, PARSE.restApiKey)

parsePhotoObj = {
	GetWhere : (where, cb)->
		params = { where: where }
		console.log('\n\n GetWhere, params=', params)
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
		console.log('\n\n UpdateSrc, objectId=', objectId)
		return parseRestClient.updateObject( 'PhotoObj'
			, objectId
			, {
				src: src
			}
			, (err, res, body, success)->
				if err || !success
					console.warn err 
					return cb()
				console.log('\n\nUPDATED PhotoObj=', body)
				return cb()
		)
}

module.exports = (Container)->

	Container.beforeRemote 'upload', (ctx, skip, next)->
		# create container if necessary
		console.log '\n\nbeforeRemote Container.upload'
		console.log ctx.req.params

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

		file.UUID = file.name.split('.')[0] #  UUID: CHAR(36) + '/L0/001', need LIKE query for this
		file.owner = file.container
		IMG_SERVER.host = ctx.req.headers.host
		file.src = [IMG_SERVER.host , IMG_SERVER.baseUrl , file.owner , file.name].join('/')

		if fields?.objectId?
			# tested OK
			parsePhotoObj.UpdateSrc(fields.objectId.shift(), file.src, next)
		else 
			# NOT TESTED
			console.log "Fields=", fields
			UUID = fields.UUID.shift() 
			ownerId = fields.owner.shift()
			whereUUID = 
				if ctx.req?.headers?['X-Image-Identifier'] 
				then ctx.req.headers['X-Image-Identifier'] 
				# else { "$regex": "^" + UUID , "$options":"i"}
				else UUID
			where = {
				UUID: whereUUID 
				src: 'queued'
				owner: { __type: 'Pointer', className: '_User', objectId: ownerId }
			}
			parsePhotoObj.GetWhere(where, (photoObjs)->
				console.log "GetWhere success, photoObjs[0]=", photoObjs[0]
				parsePhotoObj.UpdateSrc(photoObjs[0].objectId, file.src, next)
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
