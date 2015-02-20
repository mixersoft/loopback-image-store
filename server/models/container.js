'use strict';

/**
  * @ngdoc function
  * @name loopback-component-storage:container
  * @description Add remote hooks for Model:container
 */
var IMG_SERVER, Kaiseki, PARSE, _, parsePhotoObj, parseRestClient, request;

_ = require('lodash');

Kaiseki = require('kaiseki');

request = require('request');

PARSE = {
  host: 'api.parse.com',
  version: '/1/',
  baseUrl: 'classes/PhotoObj/',
  appId: 'cS8RqblszHpy6GJLAuqbyQF7Lya0UIsbcxO8yKrI',
  restApiKey: '3n5AwFGDO1n0YLEa1zLQfHwrFGpTnQUSZoRrFoD9'
};

IMG_SERVER = {
  host: null,
  baseUrl: 'storage'
};

parseRestClient = new Kaiseki(PARSE.appId, PARSE.restApiKey);

parsePhotoObj = {
  GetWhere: function(where, cb) {
    console.log('\n\n GetWhere, where=', where);
    return parseRestClient.getObject('PhotoObj', null, {
      where: where
    }, function(err, res, body, success) {
      if (err || !success) {
        console.warn(err);
        return cb();
      }
      console.log('\n\nPhotoObj=', body);
      return cb(body);
    });
  },
  UpdateSrc: function(objectId, src, cb) {
    console.log('\n\n UpdateSrc, objectId=', objectId);
    return parseRestClient.updateObject('PhotoObj', objectId, {
      src: src
    }, function(err, res, body, success) {
      if (err || !success) {
        console.warn(err);
        return cb();
      }
      console.log('\n\nUPDATED PhotoObj=', body);
      return cb();
    });
  }
};

module.exports = function(Container) {
  Container.beforeRemote('upload', function(ctx, skip, next) {
    var options, params;
    console.log('\n\nbeforeRemote Container.upload');
    console.log(ctx.req.params);
    params = ctx.req.params;
    options = {
      name: params.container
    };
    Container.createContainer(options, function(err, skip) {
      if (err && !err.code === 'EEXIST') {
        console.warn(err);
      }
      return next();
    });
  });
  return Container.afterRemote('upload', function(ctx, affectedModelInstance, next) {
    var fields, file, ref, where, whereUUID;
    console.log('\n\n afterRemote container.upload', affectedModelInstance.result);
    file = affectedModelInstance.result.files.file.shift();
    fields = affectedModelInstance.result.fields;
    file.UUID = file.name.split('.')[0];
    file.owner = file.container;
    IMG_SERVER.host = ctx.req.headers.host;
    file.src = [IMG_SERVER.host, IMG_SERVER.baseUrl, file.owner, file.name].join('/');
    if ((fields != null ? fields.objectId : void 0) != null) {
      parsePhotoObj.UpdateSrc(fields.objectId, file.src, next);
    } else {
      whereUUID = ((ref = ctx.headers) != null ? ref['X-Image-Identifier'] : void 0) ? ctx.headers['X-Image-Identifier'] : {
        "$regex": "\Q^" + file.UUID + "\E",
        "$options": "i"
      };
      where = {
        UUID: whereUUID,
        owner: {
          __type: "Pointer",
          className: "User",
          objectId: file.owner
        }
      };
      parsePhotoObj.GetWhere(where, function(photoObj) {
        return parsePhotoObj.UpdateSrc(photoObj.objectId, file.src, next);
      });
    }
  });
};
