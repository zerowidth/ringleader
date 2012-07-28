var App = Backbone.Model.extend({
  idAttribute: 'name',

  initialize: function() {
    var model = this;
    // unfortunately, there's not a nice way of updating apps collectively
    // without replacing the entire collection each time.
    this.refresh = setInterval(function() { model.fetch(); }, 5000);
  },

  url: function(extra) {
    if(extra) {
      return '/apps/' + this.get('name') + '/' + extra;
    }
    else {
      return '/apps/' + this.get('name');
    }
  },

  // for mustache, these must be exclusive
  name: function() { return this.get('name'); },
  'disabled?': function() { return !this.get('enabled'); },
  'stopped?': function() { return this.get('enabled') && !this.get('running'); },
  'running?': function() { return this.get('enabled') && this.get('running'); },

  // actions
  enable: function() { this.request('enable'); },
  disable: function() { this.request('disable'); },
  stop: function() { this.request('stop'); },
  start: function() { this.request('start'); },
  restart: function() { this.request('restart'); },

  request: function(action) {
    var model = this;
    this.set({waiting: true});
    console.log(action, this.get('name'), this.url(action));
    $.post(
      this.url(action),
      function(data) { model.set(_.extend({}, data, {waiting: false})); },
      'json');
  }
});

var Apps = Backbone.Collection.extend({
  url: '/apps',
  model: App
});

var AppControl = Backbone.View.extend({
  className: 'app',
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
    $(this.el).html(this.template.mustache(this.model));
    if(this.model.get('waiting')) {
      this.$('.buttons').hide();
      this.$('.loading').show();
    }
    else {
      this.$('.buttons').show();
      this.$('.loading').hide();
    }
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
    this.collection.fetch();

    var self = this;
  },

  addApp: function(app) {
    var view = new AppControl({model: app});
    this.$el.append(view.render().el);
  },

  addAll: function(apps) {
    this.$el.html('');
    apps.each(this.addApp, this);
  }

});

$(function() {
  window.control_panel = new ControlPanel();
});
