var PachubeTrigger = function() {
  "use strict";
  var self = this;
  self.trace("Initialising PachubeTrigger");

  self.eventListeners = {};
  self.id = null;
  self.size = null;
  self.windowProxy = new Porthole.WindowProxy('http://appdev.loc/proxy.html');
  // Register an event handler to receive messages;
  self.windowProxy.addEventListener( function(msg){ self.onMessage(msg); } );
  self.addEventListener( 'initted', function(){ self.setSize(); } );
  self.windowProxy.postMessage({action: 'init'});
  return self;
};

PachubeTrigger.prototype.trace = function(msg){
  "use strict";
  try { console.log(msg); } catch (e) { }
};

PachubeTrigger.prototype.addEventListener = function(event, listener){
  "use strict";
  if(this.eventListeners[event] === undefined){
    this.eventListeners[event] = [];
  }
  this.eventListeners[event].push(listener);
};

PachubeTrigger.prototype.triggerEvent = function(event){
  "use strict";
  if(this.eventListeners[event] !== undefined){
    $.each(this.eventListeners[event], function(id, event){ event(); });
  }
};

PachubeTrigger.prototype.setSize = function(){
  "use strict";
  if(this.id !== null){
    var size = $('body').height() + 10;
    if(this.size !== size){
      this.size = size;
      this.windowProxy.postMessage({action: 'set_size', size: size, id: this.id});
    }
  }
};

PachubeTrigger.prototype.saved = function(url){
  "use strict";
  this.windowProxy.postMessage({action: 'saved', id: this.id, trigger_url: url});
};

PachubeTrigger.prototype.ready = function(){
  "use strict";
  var self = this;
  if(self.id !== null){
    self.windowProxy.postMessage({action: 'ready', id: self.id});
  }else{
    self.addEventListener('initted', function(){ self.ready(); } );
  }
};

PachubeTrigger.prototype.onMessage = function(msg){
  "use strict";
  this.trace(msg.data.action + " received by child");
  if(msg.data.action === 'save'){
    this.triggerEvent('save');
  }else if(msg.data.action === 'initted'){
    this.id = msg.data.id;
    this.triggerEvent('initted');
    this.trace("Setting id to " + this.id);
  }else{
    this.trace("Unknown action: " + msg.data.action);
    this.trace(msg);
  }
};

PachubeTrigger.prototype.signout = function() {
  "use strict";
  var self = this;
  this.windowProxy.postMessage({action: 'notready', id: self.id});
};
