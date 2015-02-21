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
    var params;
    params = {
      where: where
    };
    console.log('\n\n GetWhere, params=', params);
    return parseRestClient['getObjects']('PhotoObj', params, function(err, res, photoObjs, success) {
      if (err || !success) {
        console.warn('ERROR: Kaiseki.getObjects() error=', err);
        return cb(false);
      }
      if ((where.UUID != null) && photoObjs.length > 1) {
        console.warn("WARNING: multiple photoObjs with the same UUID", photoObjs);
        return cb(false);
      }
      return cb(photoObjs);
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
    var UUID, fields, file, ownerId, ref, ref1, where, whereUUID;
    console.log('\n\n afterRemote container.upload', affectedModelInstance.result);
    file = affectedModelInstance.result.files.file.shift();
    fields = affectedModelInstance.result.fields;
    file.UUID = file.name.split('.')[0];
    file.owner = file.container;
    IMG_SERVER.host = ctx.req.headers.host;
    file.src = [IMG_SERVER.host, IMG_SERVER.baseUrl, file.owner, file.name].join('/');
    if ((fields != null ? fields.objectId : void 0) != null) {
      parsePhotoObj.UpdateSrc(fields.objectId.shift(), file.src, next);
    } else {
      console.log("Fields=", fields);
      UUID = fields.UUID.shift();
      ownerId = fields.owner.shift();
      whereUUID = ((ref = ctx.req) != null ? (ref1 = ref.headers) != null ? ref1['X-Image-Identifier'] : void 0 : void 0) ? ctx.req.headers['X-Image-Identifier'] : UUID;
      where = {
        UUID: whereUUID,
        src: 'queued',
        owner: {
          __type: 'Pointer',
          className: '_User',
          objectId: ownerId
        }
      };
      parsePhotoObj.GetWhere(where, function(photoObjs) {
        console.log("GetWhere success, photoObjs[0]=", photoObjs[0]);
        parsePhotoObj.UpdateSrc(photoObjs[0].objectId, file.src, next);
      });
    }
  });
};


/* 
 * 	Test Parse REST API call on bootstrap
 */
