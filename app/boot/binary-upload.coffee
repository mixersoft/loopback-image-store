'use strict'

###
 # @ngdoc function
 # @name loopback-component-storage:StorageService
 # @description override StorageService.prototype.upload to support content-type: image/jpeg
###

_ = require('lodash')
path = require('path')
fs = require('fs')
StorageHandler = require('../../node_modules/loopback-component-storage/lib//storage-handler');

module.exports = (app)->
	Container = app.models.Container
	StorageService = Container.getDataSource().connector
	FileSystemProvider = StorageService.client



	## override createContainer, change mode to 0777 and create .thumbs
	FileSystemProvider.createContainer = (options, cb)->
		FileSystemProvider.__proto__.createContainer.apply this, [
			options, 
			(err, container)->
				return cb && cb(err) if err 
				try
					dir = path.join(FileSystemProvider.root, container.name);
					if options.mode == 0o777
						fs.chmodSync(dir, 511)
					if options.thumbs
						thumbs = dir + '/.thumbs'
						fs.mkdirSync(thumbs, 511)
						fs.chmodSync(thumbs, 511)	
					cb && cb(null, container);  		
				catch err
					cb && cb(err, container);
				return
		]
		return

	# get filename with extension
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

		contentType = req.headers['content-type']
		if /^multipart\/form-data/.test( contentType )
				console.log "\n >>> multipartUpload ", _.pick req, ['params', 'headers']
				return handler.multipartUpload.apply this, arguments
		if /image\/(jpeg|png)/.test( contentType )
				# console.log "\n >>> binaryUpload ", _.pick req, ['params', 'headers']
				# image/jpeg, POST binary file upload

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


	## test, createContainer override		
	# opt = {
	# 	name: 'test-abc'
	# 	mode: 0o777
	# 	thumbs: true
	# }
	# Container.createContainer opt, (err, container)->
	# 	if err && !err.code == 'EEXIST'
	# 		console.warn err 
	# 	return 


