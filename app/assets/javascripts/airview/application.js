(function () {
  function storageKey(table) {
    return "airview:columns:" + window.location.pathname + ":" + table.dataset.airviewGridKey;
  }

  function cellAt(table, rowIndex, cellIndex) {
    var row = table.tBodies[0] && table.tBodies[0].rows[rowIndex];
    return row && row.cells[cellIndex];
  }

  function loadColumnWidths(table) {
    var raw = window.localStorage.getItem(storageKey(table));
    if (!raw) return;

    try {
      var widths = JSON.parse(raw);
      Array.prototype.forEach.call(table.querySelectorAll("th[data-airview-column]"), function (header) {
        var width = widths[header.dataset.airviewColumn];
        if (width) header.style.width = width + "px";
      });
    } catch (error) {
      window.localStorage.removeItem(storageKey(table));
    }
  }

  function saveColumnWidths(table) {
    var widths = {};
    Array.prototype.forEach.call(table.querySelectorAll("th[data-airview-column]"), function (header) {
      widths[header.dataset.airviewColumn] = header.offsetWidth;
    });
    window.localStorage.setItem(storageKey(table), JSON.stringify(widths));
  }

  document.addEventListener("DOMContentLoaded", function () {
    Array.prototype.forEach.call(document.querySelectorAll("[data-airview-grid] table"), function (table, index) {
      table.dataset.airviewGridKey = String(index);
      loadColumnWidths(table);
    });
  });

  document.addEventListener("mousedown", function (event) {
    if (!event.target.matches("[data-airview-resizer]")) return;

    var header = event.target.closest("th");
    var table = header.closest("table");
    var startX = event.clientX;
    var startWidth = header.offsetWidth;

    function move(moveEvent) {
      var width = Math.max(120, startWidth + moveEvent.clientX - startX);
      header.style.width = width + "px";
    }

    function stop() {
      document.removeEventListener("mousemove", move);
      document.removeEventListener("mouseup", stop);
      saveColumnWidths(table);
    }

    event.preventDefault();
    document.addEventListener("mousemove", move);
    document.addEventListener("mouseup", stop);
  });

  document.addEventListener("keydown", function (event) {
    var cell = event.target.closest && event.target.closest(".airview-grid td");
    if (!cell) return;

    var table = cell.closest("table");
    var row = cell.parentElement;
    var rowIndex = row.rowIndex - 1;
    var cellIndex = cell.cellIndex;
    var next = null;

    if (event.key === "ArrowRight") next = cellAt(table, rowIndex, cellIndex + 1);
    if (event.key === "ArrowLeft") next = cellAt(table, rowIndex, cellIndex - 1);
    if (event.key === "ArrowDown") next = cellAt(table, rowIndex + 1, cellIndex);
    if (event.key === "ArrowUp") next = cellAt(table, rowIndex - 1, cellIndex);

    if (next) {
      event.preventDefault();
      next.focus();
      var input = next.querySelector("input:not([type=hidden]), textarea, select");
      if (input) input.focus();
    }
  });

  document.addEventListener("keydown", function (event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      var form = event.target.closest && event.target.closest(".airview-cell-form");
      if (form) {
        event.preventDefault();
        form.requestSubmit();
      }
    }
  });
})();
