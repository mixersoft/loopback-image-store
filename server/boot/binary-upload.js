'use strict';

/*
  * @ngdoc function
  * @name loopback-component-storage:StorageService
  * @description override StorageService.prototype.upload to support content-type: image/jpeg
 */
var StorageHandler, _;

_ = require('lodash');

StorageHandler = require('../../node_modules/loopback-component-storage/lib//storage-handler');

module.exports = function(app) {
  var Container, StorageService, binaryUpload, getFilename, handler;
  Container = app.models.Container;
  StorageService = Container.getDataSource().connector;
  getFilename = function(UUID, mime) {
    var parts;
    parts = [UUID.replace(/\//g, '_')];
    switch (mime) {
      case 'image/jpeg':
        parts.push('jpg');
        break;
      case 'image/png':
        parts.push('png');
    }
    return parts.join('.');
  };
  binaryUpload = function(provider, req, res, options, cb) {
    var err, fields, file, files, uploadParams, writer;
    if (!cb && _.isFunction(options)) {
      cb = options;
      options = {};
    }
    if (req.headers['content-type'] !== 'image/jpeg') {
      console.log("\n >>> multipartUpload ", arguments);
      return handler.multipartUpload.apply(this, arguments);
    }
    console.log("\n >>> binaryUpload!!!");
    console.log('provider=', provider);
    console.log('params=', req.params);
    console.log('headers=', req.headers);
    file = {
      container: req.headers['x-container-identifier'],
      UUID: req.headers['x-image-identifier'],
      name: getFilename(req.headers['x-image-identifier'], req.headers['content-type']),
      type: req.headers['content-type']
    };
    files = fields = {};
    req.on('end', function() {
      writer.end();
      fields = {
        owner: [file.container],
        objectId: [],
        UUID: [file.UUID]
      };
      files = {
        file: [file]
      };
      cb && cb(null, {
        files: files,
        fields: fields
      });
    });
    try {
      uploadParams = {
        container: file.container,
        remote: file.name,
        contentType: file.type
      };
      if (file['acl'] != null) {
        uploadParams['acl'] = file['acl'];
      }
      writer = provider.upload(uploadParams);
      req.pipe(writer, {
        end: false
      });
      return;
    } catch (_error) {
      err = _error;
      cb && cb(err, {
        files: files,
        fields: fields
      });
      return;
    }
  };
  handler = StorageHandler;
  handler.multipartUpload = handler.upload;
  handler.upload = handler.binaryUpload = binaryUpload;
};
