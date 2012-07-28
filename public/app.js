var App = Backbone.Model.extend({
  url: function(extra) {
    return this.urlRoot + '/' + this.get('name') + extra;
  },
  enable: function() { this.request('enable'); },
  disable: function() { this.request('disable'); },
  stop: function() { this.request('stop'); },
  start: function() { this.request('start'); },
  restart: function() { this.request('restart'); },
  request: function(action) {
    console.log(action, this.get('name'));
    $.post({
      url: this.url('/' + action)
    });
  }
});

var Apps = Backbone.Collection.extend({
  url: '/apps',
  model: App
});

var AppControl = Backbone.View.extend({
  tagName: 'tr',
  initialize: function() {
    this.template = $('#app-template');
    this.model.bind('change', this.render, this);
  },
  events: {
    'click .start'   : 'start',
    'click .stop'    : 'stop',
    'click .restart' : 'restart',
    'click .enable'  : 'enable',
    'click .disable' : 'disable'
  },
  render: function() {
    $(this.el).html(this.template.mustache(this.model.toJSON()));
    return this;
  },
  start: function() { this.model.start(); return false; },
  stop: function() { this.model.stop(); return false; },
  restart: function() { this.model.restart(); return false; },
  enable: function() { this.model.enable(); return false; },
  disable: function() { this.model.disable(); return false; }
});

var ControlPanel = Backbone.View.extend({
  el: $('#apps'),
  initialize: function(options) {
    this.collection = new Apps();
    this.collection.bind('add', this.addApp, this);
    this.collection.bind('reset', this.addAll, this);
  },

  addApp: function(app) {
    var view = new AppControl({model: app});
    this.$el.append(view.render().el);
  },

  addAll: function(apps) {
    apps.each(this.addApp, this);
  }

});

$(function() {
  window.control_panel = new ControlPanel();
  control_panel.collection.reset([
    { name: 'main_site', 'running?': true },
    { name: 'admin_app', 'stopped?': true },
    { name: 'resque_workers', 'disabled?': true }
  ]);

});
