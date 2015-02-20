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
		console.log('\n\n GetWhere, where=', where)
		return parseRestClient.getObject( 'PhotoObj'
			, null
			, {
				where: where
			}
			, (err, res, body, success)->
				if err || !success
					console.warn err 
					return cb()
				console.log('\n\nPhotoObj=', body)
				return cb(body)
				# return parsePhotoObj.UpdateSrc(body.objectId, file.src, cb)
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
		# fields={owner, objectId}		
		file = affectedModelInstance.result.files.file.shift()
		fields = affectedModelInstance.result.fields

		file.UUID = file.name.split('.')[0] #  UUID: CHAR(36) + '/L0/001', need LIKE query for this
		file.owner = file.container
		IMG_SERVER.host = ctx.req.headers.host
		file.src = [IMG_SERVER.host , IMG_SERVER.baseUrl , file.owner , file.name].join('/')

		if fields?.objectId?
			# tested OK
			parsePhotoObj.UpdateSrc(fields.objectId, file.src, next)
		else 
			# NOT TESTED
			whereUUID = 
				if ctx.headers?['X-Image-Identifier'] 
				then ctx.headers['X-Image-Identifier'] 
				else { "$regex": "\Q^" + file.UUID + "\E", "$options":"i"}
			where = {
				UUID: whereUUID  
				owner: 
					__type: "Pointer"
					className: "User"
					objectId: file.owner
			}
			parsePhotoObj.GetWhere(where,  (photoObj)->
				parsePhotoObj.UpdateSrc(photoObj.objectId, file.src, next)
			)
		return


