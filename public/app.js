$(function() {
  var apps = [
    { name: 'main_site', 'running?': true },
    { name: 'admin_app', 'stopped?': true },
    { name: 'resque_workers', 'disabled?': true }
  ];
  var template = $('#app-template');
  _.each(apps, function(app) {
    $('#apps').append( template.mustache(app) );
  });
});
