'use strict'

###
 # @ngdoc function
 # @name loopback-component-storage:StorageService
 # @description override StorageService.prototype.upload to support content-type: image/jpeg
###

_ = require('lodash')
StorageHandler = require('../../node_modules/loopback-component-storage/lib//storage-handler');


module.exports = (app)->
	Container = app.models.Container
	StorageService = Container.getDataSource().connector
	# console.log 'keys', _.keys Container

	getFilename = (UUID, mime)->
		parts = [UUID.replace(/\//g,'_')]
		switch mime
			when 'image/jpeg'
				parts.push 'jpg'
			when 'image/png'
				parts.push 'png'
		return parts.join('.')

	binaryUpload = (provider, req, res, options, cb)->
		if !cb && _.isFunction options
			cb = options
			options = {}

		if req.headers['content-type'] != 'image/jpeg'
			console.log "\n >>> multipartUpload ", arguments
			return handler.multipartUpload.apply this, arguments

		console.log "\n >>> binaryUpload!!!"
		# image/jpeg, POST binary file upload
		console.log('provider=', provider);
		console.log('params=', req.params);
		console.log('headers=', req.headers);

		file = {
			container: req.headers['x-container-identifier']
			UUID: req.headers['x-image-identifier']
			name: getFilename( req.headers['x-image-identifier'], req.headers['content-type'] )
			type: req.headers['content-type']
		}
		# provider instanceof FileSystemProvider

		files = fields = {}
		req.on 'end', ()->
			writer.end()
			# endFunc()
			fields = {
				owner: [file.container]
				objectId: []
				UUID: [file.UUID]
			}
			files = {
				file: [file]
			}
			cb && cb(null, {files: files, fields: fields});
			return 

		try
			uploadParams =  {
				container: file.container, 
				remote: file.name, 
				contentType: file.type
			}
			uploadParams['acl'] = file['acl'] if file['acl']?
			writer = provider.upload(uploadParams) # = fs.createWriteStream()
			req.pipe writer, {end:false}
			return
		catch err
			cb && cb(err, {files: files, fields: fields});
			return

		return # end binaryUpload()


	# override StorageService.prototype.upload > handler.upload
	handler = StorageHandler
	handler.multipartUpload = handler.upload
	handler.upload = handler.binaryUpload = binaryUpload
	return
