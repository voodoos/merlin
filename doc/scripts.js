function toggle(id) {
  var x = document.getElementById(id);
  if (x.style.display === "none") {
    x.style.display = "table-row";
  } else {
    x.style.display = "none";
  }
}
