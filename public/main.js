get_time = function(){
  return '2011-07-07 15:09:14'
}

get_value = function(){
  var triggerval = $('#thresholdvalue').val()
  if (triggerval != '') {
    return triggerval
  } else {
    return '(a value)'
  }
}

preview_tweet = function(){
  tweet = $('#tweet').val()
    .replace('{datastream}', 'energy')
    .replace('{feed}', '1234')
    .replace('{feed_url}', "http://pachu.be/" + '1234')
    .replace('{time}', get_time())
    .replace('{value}', '234.4');
  $('#previewtweet').text(tweet);
}

$('#tweet').keyup(preview_tweet);
$('#thresholdvalue').keyup(preview_tweet);
preview_tweet();

