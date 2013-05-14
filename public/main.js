// Not sure about having this here, but not sure where else to put it.
$('#twittertrigger-signout').click(function(event) {
  "use strict";
  event.preventDefault();
  $.ajax({
    type: 'POST',
    url: '/auth/twitter/unauthenticate',
    success: function(data) {
      pbt.postMessage({action: 'notready'});
      pbt.postMessage({action: 'redirect', url: window.location.protocol + '//' + window.location.host + '/triggers/new'});
    }
  });
});

var get_time = function() {
  "use strict";
  return '2011-07-07 15:09:14';
};

var get_value = function() {
  "use strict";
  var triggerval = $('#thresholdvalue').val();
  if (triggerval !== '') {
    return triggerval;
  } else {
    return '(a value)';
  }
};

var update_tweet_counter = function(length) {
  "use strict";
  var remaining = 130 - length;
  $('#tweet-counter').html(remaining);
  if (remaining < 0) {
    $('#tweet-status').html("over");
    $('.tweet-counter').addClass('tweet-counter-warning');
  } else {
    $('#tweet-status').html("remaining");
    $('.tweet-counter').removeClass('tweet-counter-warning');
  }
};

var preview_tweet = function() {
  "use strict";
  var tweet = $('#tweet').val()
    .replace('{datastream}', 'energy')
    .replace('{feed}', '1234')
    .replace('{feed_url}', "https://xively.com/feeds/" + '1234')
    .replace('{time}', get_time())
    .replace('{value}', '234.4');
  $('#previewtweet').text(tweet);
  update_tweet_counter(tweet.length);
};


$('#tweet').keyup(preview_tweet);
$('#thresholdvalue').keyup(preview_tweet);
preview_tweet();

