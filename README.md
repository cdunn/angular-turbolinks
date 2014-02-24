# Angular::Turbolinks

##### Add angular-turbolinks and turbolinks to your Gemfile
```sh
gem "turbolinks"
gem "angular-turbolinks"
```

##### Add angular-route and angular-turbolinks to your sprockets
```sh
//= require angular-route
//= require angular-turbolinks
```

##### Add 'ngTurbolinks' and 'ngRoute' to your angular.module
```sh
var app = angular.module('...', [..., 'ngRoute', 'ngTurbolinks'])
```

##### Make sure HTML5 mode is enabled...
```sh
app.config([
  "$locationProvider", function($locationProvider) {
    $locationProvider.html5Mode(true);
  }
]);
```
##### Add ng-app to the html element
<html ng-app='myapp'>

##### (optional) Broadcast angular $destroy for you to remove any global listeners (window, pending http, etc)
```sh
$(document).on('page:before-change', ->
  angular.element("body").scope().$broadcast("$destroy")
)
```

##### Notes
* This is a first stab just to try to get around the '10 $digest() iterations reached using $locationWatch' errors I was receiving when using turbolinks with angular when using the approach of re-bootstrapping the ng-app on turbolinks page:load 
  * https://github.com/angular/angular.js/issues/3915
  * https://github.com/angular/angular.js/issues/2815 (among others)
  * none of the suggested fixes worked for me and this was happening on chrome
* This approach uses the angular $location/$locationProvider services for click tracking and pushState, steals the $locationChangeStart event and runs the changed url through turbolinks methods
* Does not support any of the turbolinks caching
* Eventually im hoping angular $locationWatch can play nice with external plugins using pushState...

##### TODO
* add support for turbolinks redirection logic (referer not working properly (ie. redirect_to :back))
