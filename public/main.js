// Not sure about having this here, but not sure where else to put it.
$('#twittertrigger-signout').click(function(event) {
  "use strict";
  event.preventDefault();
  $.ajax({
    type: 'POST',
    url: '/auth/twitter/unauthenticate',
    success: function(data) {
      pbt.signout();
      window.location.href = "/login";
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
  var remaining = 140 - length;
  $('#tweet-counter').val(remaining);
  if (remaining < 0) {
    $('#tweet-counter').addClass('tweet-counter-warning');
  } else {
    $('#tweet-counter').removeClass('tweet-counter-warning');
  }
};

var preview_tweet = function() {
  "use strict";
  var tweet = $('#tweet').val()
    .replace('{datastream}', 'energy')
    .replace('{feed}', '1234')
    .replace('{feed_url}', "http://pachu.be/" + '1234')
    .replace('{time}', get_time())
    .replace('{value}', '234.4');
  $('#previewtweet').text(tweet);
  update_tweet_counter(tweet.length);
};


$('#tweet').keyup(preview_tweet);
$('#thresholdvalue').keyup(preview_tweet);
preview_tweet();

