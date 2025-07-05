$(function() {

  $("form.login").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var form = $(this);
    var name = form.attr("value");
    var ok = confirm("Do you want to play as " + name + "?");

    if (ok) {
      this.submit()
    }
  });

});
