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
  host: 'http://snappi.snaphappi.com',
  baseUrl: 'svc/storage'
};

parseRestClient = new Kaiseki(PARSE.appId, PARSE.restApiKey);

parsePhotoObj = {
  GetWhere: function(where, cb) {
    var params;
    params = {
      where: where
    };
    console.log('GetWhere, params=', params);
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
    console.log('UpdateSrc, data=', {
      objectId: objectId,
      src: src
    });
    return parseRestClient.updateObject('PhotoObj', objectId, {
      src: src
    }, function(err, res, body, success) {
      if (err || !success) {
        console.warn(err);
        return cb();
      }
      console.log('UPDATED PhotoObj=', body);
      return cb();
    });
  }
};

module.exports = function(Container) {
  Container.beforeRemote('upload', function(ctx, skip, next) {
    var options, params;
    console.log('\n\nbeforeRemote Container.upload');
    console.log("params", ctx.req.params);
    console.log("headers", ctx.req.headers);
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
    var fields, file, where;
    console.log('\n\n afterRemote container.upload', affectedModelInstance.result);
    file = affectedModelInstance.result.files.file.shift();
    fields = affectedModelInstance.result.fields;
    if (!file.UUID) {
      file.UUID = file.name.split('.')[0];
    }
    file.owner = file.container;
    file.src = [IMG_SERVER.host, IMG_SERVER.baseUrl, file.owner, file.name].join('/');
    if (!_.isEmpty(fields != null ? fields.objectId : void 0)) {
      parsePhotoObj.UpdateSrc(fields.objectId.shift(), file.src, next);
    } else {
      console.log("file=", file);
      where = {
        UUID: file.UUID,
        owner: {
          __type: 'Pointer',
          className: '_User',
          objectId: file.owner
        }
      };
      parsePhotoObj.GetWhere(where, function(photoObjs) {
        console.log("GetWhere success, photoObjs[0]=", _.pick(photoObjs[0], ['UUID', 'owner', 'src', 'workorder']));
        if (_.isEmpty(photoObjs)) {
          return next();
        }
        parsePhotoObj.UpdateSrc(photoObjs[0].objectId, file.src, function() {
          if (ctx.req.headers['content-type'] === 'image/jpeg') {
            return ctx.res.set('Location', file.src).status(201).send();
          } else {
            return next();
          }
        });
      });
    }
  });
};


/* 
 * 	Test Parse REST API call on bootstrap
 */
