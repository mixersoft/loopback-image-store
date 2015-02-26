'use strict';

/*
  * @ngdoc function
  * @name loopback-component-storage:StorageService
  * @description override StorageService.prototype.upload to support content-type: image/jpeg
 */
var StorageHandler, _, fs, path;

_ = require('lodash');

path = require('path');

fs = require('fs');

StorageHandler = require('../../node_modules/loopback-component-storage/lib//storage-handler');

module.exports = function(app) {
  var Container, FileSystemProvider, StorageService, binaryUpload, getFilename, handler;
  Container = app.models.Container;
  StorageService = Container.getDataSource().connector;
  FileSystemProvider = StorageService.client;
  FileSystemProvider.createContainer = function(options, cb) {
    FileSystemProvider.__proto__.createContainer.apply(this, [
      options, function(err, container) {
        var dir, thumbs;
        if (err) {
          return cb && cb(err);
        }
        try {
          dir = path.join(FileSystemProvider.root, container.name);
          if (options.mode === 0x1ff) {
            fs.chmodSync(dir, 511);
          }
          if (options.thumbs) {
            thumbs = dir + '/.thumbs';
            fs.mkdirSync(thumbs, 511);
            fs.chmodSync(thumbs, 511);
          }
          cb && cb(null, container);
        } catch (_error) {
          err = _error;
          cb && cb(err, container);
        }
      }
    ]);
  };
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
    var contentType, err, fields, file, files, uploadParams, writer;
    if (!cb && _.isFunction(options)) {
      cb = options;
      options = {};
    }
    contentType = req.headers['content-type'];
    if (/^multipart\/form-data/.test(contentType)) {
      console.log("\n >>> multipartUpload ", _.pick(req, ['params', 'headers']));
      return handler.multipartUpload.apply(this, arguments);
    }
    if (/image\/(jpeg|png)/.test(contentType)) {
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
    }
  };
  handler = StorageHandler;
  handler.multipartUpload = handler.upload;
  handler.upload = handler.binaryUpload = binaryUpload;
};
