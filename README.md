# Angular::Turbolinks

##### Add angular-turbolinks and turbolinks to your Gemfile
```sh
gem "turbolinks"
gem "angular-turbolinks"
```

##### Add angular-turbolinks to your sprockets
```sh
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

##### Move angular bootstrapping to turbolinks event
```sh
$(document).on('ready page:load', ->
  angular.bootstrap($("body"), ['app'])
).on('page:before-change', ->
  angular.element("body").scope().$broadcast("$destroy")
)
```

##### TODO
* add support for turbolinks redirection logic
* referer not working properly (ie. redirect_to :back)

##### Caveats
* This is a first stab just to try to get around the '10 $digest() iterations reached using $locationWatch' errors I was receiving when using turbolinks with angular
  * https://github.com/angular/angular.js/issues/3915
  * https://github.com/angular/angular.js/issues/2815 (among others)
  * none of the suggested fixes worked for me and this was happening on chrome
* This approach uses the angular $location/$locationProvider services for click tracking and pushState, steals the $locationChangeStart event and runs the changed url through turbolinks methods
* Does not support any of the turbolinks caching
* Eventually im hoping angular $locationWatch can play nice with external plugins using pushState...
