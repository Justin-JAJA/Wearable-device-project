document.addEventListener('DOMContentLoaded',function(){
  document.querySelectorAll('details').forEach(function(d){d.setAttribute('aria-label',d.querySelector('summary').textContent);});
  window.addEventListener('beforeprint',function(){document.querySelectorAll('details').forEach(function(d){d.dataset.wasOpen=d.open?'1':'0';d.open=true;});});
  window.addEventListener('afterprint',function(){document.querySelectorAll('details').forEach(function(d){d.open=d.dataset.wasOpen==='1';});});
});
