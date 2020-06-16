'use strict';

module.exports = function(grunt) {

  grunt.loadNpmTasks('grunt-mocha-test');

  grunt.initConfig({
    mochaTest: {
      test: {
        options: {
          reporter: 'spec',
          require: 'coffee-script'
        },
        src: ['test/**/*.coffee']
      }
    },
    watch: {
      files: ['Gruntfile.js', 'test/**/*.coffee'],
      tasks: ['test']
    }
  });

  grunt.event.on('watch', function(action, filepath, target) {
    grunt.log.writeln(target + ': ' + filepath + ' has ' + action);
  });

  // load all grunt tasks
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks);

  grunt.registerTask('test', ['mochaTest']);
  grunt.registerTask('test:watch', ['watch']);
  grunt.registerTask('default', ['test']);
};
