// debug-index.controller.js
'use strict';

angular.module('arachne')
.controller('DebugIndexController', ['$http', function($http) {
    var controller = this;

    //-------------------------------------------
    // Tab Management

    var tab = 'code';

    this.setTab = function(which) {
        tab = which;
    };
    this.active = function(which) {
        return tab === which;
    };
    this.tab = function() {
        return tab;
    }

    //--------------------------------------------
    // Mods

    this.mods = [];     // List of loaded mods

    this.retrieveMods = function (reloadFlag) {
        var url = '/debug/mods.json';

        if (reloadFlag) {
            url += '?op=reload';
        }

        $http.get(url).success(function(data) {
            controller.mods = data;
        });
    };

    //--------------------------------------------
    // Code Search

    this.cmdline = '';
    this.found = {
        cmdline: '',
        code:    ''
    };

    this.codeSearch = function() {
        this.found.cmdline = this.cmdline;
        this.cmdline = '';
        $http.get('/debug/code.json', {
            params: {cmdline: this.found.cmdline}
        }).success(function(data) {
            if (data[1] !== '') {
                controller.found.code = data[1];
            } else {
                controller.found.code = "No matching code found."
            }
        }).error(function(data) {
            controller.found.code = '';
        });
    };

    //--------------------------------------------
    // Logs

    this.logArea  = '';     // Log Area displayed in logs tab
    this.logFile  = '';     // Log File displayed in logs tab
    this.logs = {};         // Dictionary of Log Files by Log Area
    this.logEntries = [];   // Array of log entries for the selected log

    this.logRetrieve = function() {
        // FIRST, get the available areas.
        $http.get('/debug/logs.json').success(function(data) {
            var areas = Object.keys(data);
            controller.logs = data;
            console.log(data);

            if (!controller.gotArea(controller.logArea)) {
                controller.logArea = '';
            }

            if (!controller.gotFile(controller.logFile)) {
                controller.logFile = '';
            }
        })
    }

    this.logAreas = function() {
        return Object.keys(this.logs);
    }

    this.logFiles = function() {
        return this.logs[this.logArea];
    }

    this.gotArea = function(area) {
        var areas = Object.keys(this.logs);
        return areas.indexOf(area) !== -1;
    }

    this.gotFile = function(file) {
        if (!this.logArea) {
            return false;
        }

        return this.logs[this.logArea].indexOf(file) !== -1;
    }

    this.setArea = function(area) {
        console.log("setArea: " + area);
        this.logArea = area;
        this.logFile = this.logs[area][this.logs[area].length - 1];
        this.setTab('logs');
        this.showLog();
    };

    this.setFile = function(file) {
        console.log("setFile: " + file);
        this.logFile = file;
        this.setTab('logs');
        this.showLog();
    };

    this.showLog = function() {
        // TBD: Retrieve the desired log.
        this.logEntries = [];
    }

    //--------------------------------------------
    // Initialization

    this.retrieveMods();
    this.logRetrieve();
}]);