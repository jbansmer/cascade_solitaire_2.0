$(function() {

  $("form.login").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var form = $(this);
    var ok = confirm("Are you sure about that name?");

    if (ok) {
      this.submit()
    }
  });

});
