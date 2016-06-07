angular.module('app', ['angularFileUpload'])

  // The example of the full functionality
  .controller('TestController',function ($scope, $fileUploader) {
    'use strict';

    // create a uploader with options
    var uploader = $scope.uploader = $fileUploader.create({
      scope: $scope,                          // to automatically update the html. Default: $rootScope
      url: '/api/containers/fNnreAFrrcsiX4syj/upload',
      headers: {
        'X-Image-Identifier': '00000000-081d-405a-a831-cc44ae62c26f',
        'X-Container-Identifier' : 'fNnreAFrrcsiX4syj',
        'X-App-Identifier' : 'macata'
      },
      formData: [
        { }
      ],
      filters: [
        function (item) {                    // first user filter
          console.info('filter1');
          return true;
        }
      ]
    });

    // ADDING FILTERS

    uploader.filters.push(function (item) { // second user filter
      console.info('filter2');
      return true;
    });

    uploader.filters.push(
      function(item, options) {
        var type;
        console.info('imageFilter');
        type = '|' + item.type.slice(item.type.lastIndexOf('/') + 1) + '|';
        return ~'|jpg|png|jpeg|'.indexOf(type);
      }
    )

    // REGISTER HANDLERS

    uploader.bind('afteraddingfile', function (event, item) {
      console.info('After adding a file', item);
    });

    uploader.bind('whenaddingfilefailed', function (event, item) {
      console.info('When adding a file failed', item);
    });

    uploader.bind('afteraddingall', function (event, items) {
      console.info('After adding all files', items);
    });

    uploader.bind('beforeupload', function (event, item) {
      console.info('Before upload', item);
      // item.headers['Content-Type'] = item.file.type
    });

    uploader.bind('progress', function (event, item, progress) {
      console.info('Progress: ' + progress, item);
    });

    uploader.bind('success', function (event, xhr, item, response) {
      console.info('Success', xhr, item, response);
      $scope.$broadcast('uploadCompleted', item);
    });

    uploader.bind('cancel', function (event, xhr, item) {
      console.info('Cancel', xhr, item);
    });

    uploader.bind('error', function (event, xhr, item, response) {
      console.info('Error', xhr, item, response);
    });

    uploader.bind('complete', function (event, xhr, item, response) {
      console.info('Complete', xhr, item, response);
    });

    uploader.bind('progressall', function (event, progress) {
      console.info('Total progress: ' + progress);
    });

    uploader.bind('completeall', function (event, items) {
      console.info('Complete all', items);
    });

  }
).controller('FilesController', function ($scope, $http) {

    $scope.load = function () {
      $http.get('/api/containers/container1/files').success(function (data) {
        console.log(data);
        $scope.files = data;
      });
    };

    $scope.delete = function (index, id) {
      $http.delete('/api/containers/container1/files/' + encodeURIComponent(id)).success(function (data, status, headers) {
        $scope.files.splice(index, 1);
      });
    };

    $scope.$on('uploadCompleted', function(event) {
      console.log('uploadCompleted event received');
      $scope.load();
    });

  });
