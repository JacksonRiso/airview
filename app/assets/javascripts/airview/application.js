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
        if (width) setColumnWidth(table, header, width);
      });
    } catch (error) {
      window.localStorage.removeItem(storageKey(table));
    }
  }

  function columnForHeader(table, header) {
    return table.querySelector('col[data-airview-column-width="' + header.dataset.airviewColumn + '"]');
  }

  function setColumnWidth(table, header, width) {
    var column = columnForHeader(table, header);
    var value = Math.max(64, width) + "px";

    if (column) column.style.width = value;
    header.style.width = value;
  }

  function saveColumnWidths(table) {
    var widths = {};
    Array.prototype.forEach.call(table.querySelectorAll("th[data-airview-column]"), function (header) {
      widths[header.dataset.airviewColumn] = header.offsetWidth;
    });
    window.localStorage.setItem(storageKey(table), JSON.stringify(widths));
  }

  var referenceSearchTimers = new WeakMap();

  function escapeHtml(value) {
    return String(value || "").replace(/[&<>"']/g, function (character) {
      return {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#039;"
      }[character];
    });
  }

  function referenceElements(element) {
    var wrapper = element.closest(".airview-reference-picker");

    return {
      wrapper: wrapper,
      hidden: wrapper && wrapper.parentElement.querySelector("[data-airview-reference-target]"),
      input: wrapper && wrapper.querySelector("[data-airview-reference-picker]"),
      results: wrapper && wrapper.querySelector("[data-airview-reference-results]"),
      preview: wrapper && wrapper.parentElement.querySelector("[data-airview-reference-preview]")
    };
  }

  function setReferencePreview(preview, record) {
    if (!preview) return;

    if (!record) {
      preview.classList.add("is-empty");
      preview.innerHTML = "+ Link record";
      return;
    }

    var detailText = (record.preview || []).map(function (item) {
      return item.label + ": " + item.value;
    }).join(" · ");

    preview.classList.remove("is-empty");
    preview.innerHTML = [
      '<div class="airview-reference-preview-title">' + escapeHtml(record.label) + '</div>',
      detailText ? '<div class="airview-reference-preview-details">' + escapeHtml(detailText) + '</div>' : "",
      record.open_url ? '<a class="airview-reference-open" href="' + escapeHtml(record.open_url) + '">Open record</a>' : ""
    ].join("");
  }

  function renderReferenceResults(elements, records) {
    if (!elements.results) return;

    if (!records.length) {
      elements.results.innerHTML = '<div class="airview-reference-no-results">No matching records</div>';
      elements.results.classList.add("is-open");
      return;
    }

    elements.results.innerHTML = records.map(function (record) {
      var details = (record.preview || []).slice(0, 3).map(function (item) {
        return item.label + ": " + item.value;
      }).join(" · ");

      return [
        '<button type="button" class="airview-reference-result" data-airview-reference-result',
        ' data-record-id="' + escapeHtml(record.id) + '"',
        ' data-record-label="' + escapeHtml(record.label) + '"',
        ' data-record-payload="' + escapeHtml(JSON.stringify(record)) + '">',
        '<span class="airview-reference-result-title">' + escapeHtml(record.label) + '</span>',
        '<span class="airview-reference-result-meta">Id: ' + escapeHtml(record.id) + (details ? " · " + escapeHtml(details) : "") + '</span>',
        '</button>'
      ].join("");
    }).join("");
    elements.results.classList.add("is-open");
  }

  function searchReferencePicker(input, clearValue) {
    var elements = referenceElements(input);
    if (!elements.wrapper || !elements.results) return;

    window.clearTimeout(referenceSearchTimers.get(input));
    referenceSearchTimers.set(input, window.setTimeout(function () {
      var url = new URL(elements.wrapper.dataset.airviewReferenceUrl, window.location.origin);
      var query = input.value.trim();
      if (clearValue && elements.hidden) elements.hidden.value = "";
      if (query) url.searchParams.set("q", query);

      elements.results.innerHTML = '<div class="airview-reference-no-results">Searching...</div>';
      elements.results.classList.add("is-open");

      window.fetch(url.toString(), { headers: { Accept: "application/json" } })
        .then(function (response) { return response.json(); })
        .then(function (records) { renderReferenceResults(elements, records); })
        .catch(function () {
          elements.results.innerHTML = '<div class="airview-reference-no-results">Unable to load records</div>';
          elements.results.classList.add("is-open");
        });
    }, 180));
  }

  function selectReferenceResult(button) {
    var elements = referenceElements(button);
    if (!elements.hidden || !elements.input) return;

    var record = JSON.parse(button.dataset.recordPayload);
    elements.hidden.value = button.dataset.recordId;
    elements.input.value = button.dataset.recordLabel;
    if (elements.results) elements.results.classList.remove("is-open");
    setReferencePreview(elements.preview, record);

    var form = button.closest(".airview-cell-form");
    if (form) form.requestSubmit();
  }

  function filterFieldList(input) {
    var query = input.value.toLowerCase().trim();
    var panel = input.closest(".airview-popover-panel");
    if (!panel) return;

    Array.prototype.forEach.call(panel.querySelectorAll("[data-airview-field-list-item]"), function (item) {
      item.classList.toggle("is-hidden", !item.dataset.airviewFieldListItem.includes(query));
    });
  }

  function filterFieldPickerElements(element) {
    var picker = element.closest("[data-airview-filter-field-picker]");
    var row = picker && picker.closest("[data-airview-filter-condition]");

    return {
      picker: picker,
      row: row,
      input: picker && picker.querySelector("[data-airview-filter-field-search]"),
      results: picker && picker.querySelector("[data-airview-filter-field-results]"),
      hidden: row && row.querySelector("[data-airview-field-target]")
    };
  }

  function searchFilterFieldPicker(input) {
    var elements = filterFieldPickerElements(input);
    var query = input.value.toLowerCase().trim();
    if (!elements.results) return;

    Array.prototype.forEach.call(elements.results.querySelectorAll("[data-airview-filter-field-option]"), function (option) {
      var text = [option.dataset.fieldLabel, option.dataset.fieldName].join(" ").toLowerCase();
      option.classList.toggle("is-hidden", !text.includes(query));
    });

    elements.results.classList.add("is-open");
  }

  function operatorOptionsForFieldType(fieldType) {
    if (fieldType === "boolean") return [["is checked", "is_true"], ["is unchecked", "is_false"]];
    if (["integer", "float", "decimal"].includes(fieldType)) {
      return [["=", "equals"], [">", "gt"], ["<", "lt"], [">=", "gte"], ["<=", "lte"], ["is empty", "is_empty"], ["is not empty", "is_not_empty"]];
    }
    if (["date", "datetime"].includes(fieldType)) return [["is", "equals"], ["before", "before"], ["after", "after"], ["is empty", "is_empty"], ["is not empty", "is_not_empty"]];

    return [["contains", "contains"], ["equals", "equals"], ["starts with", "starts_with"], ["is empty", "is_empty"], ["is not empty", "is_not_empty"]];
  }

  function updateFilterOperator(row, fieldType) {
    var select = row.querySelector('select[name$="[operator]"]');
    if (!select) return;

    select.innerHTML = operatorOptionsForFieldType(fieldType).map(function (option) {
      return '<option value="' + escapeHtml(option[1]) + '">' + escapeHtml(option[0]) + '</option>';
    }).join("");
  }

  function updateFilterValue(row, fieldType) {
    var current = row.querySelector("[data-airview-filter-value]");
    if (!current) return;

    var name = current.name;
    var replacement;

    if (fieldType === "boolean") {
      replacement = document.createElement("select");
      replacement.innerHTML = '<option value="true">checked</option><option value="false">unchecked</option>';
    } else {
      replacement = document.createElement("input");
      replacement.placeholder = fieldType === "date" || fieldType === "datetime" ? "" : "Value";
      replacement.type = ["date", "datetime"].includes(fieldType) ? "date" : ["integer", "float", "decimal"].includes(fieldType) ? "number" : "text";
      if (replacement.type === "number") replacement.step = "any";
    }

    replacement.name = name;
    replacement.dataset.airviewFilterValue = "true";
    current.replaceWith(replacement);
  }

  function selectFilterField(button) {
    var elements = filterFieldPickerElements(button);
    if (!elements.input || !elements.hidden || !elements.results) return;

    elements.input.value = button.dataset.fieldLabel;
    elements.hidden.value = button.dataset.fieldName;
    elements.results.classList.remove("is-open");
    updateFilterOperator(elements.row, button.dataset.fieldType);
    updateFilterValue(elements.row, button.dataset.fieldType);
  }

  function toggleModalHiddenField(checkbox) {
    var modal = checkbox.closest("[data-airview-modal]");
    if (!modal) return;

    var selector = '[data-airview-modal-hidden-field="' + checkbox.dataset.airviewModalFieldToggle + '"]';
    var row = modal.querySelector(selector);
    if (row) row.classList.toggle("is-hidden", !checkbox.checked);
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
      var width = Math.max(64, startWidth + moveEvent.clientX - startX);
      setColumnWidth(table, header, width);
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

  document.addEventListener("click", function (event) {
    if (event.target.matches("[data-airview-add-filter]")) {
      var form = event.target.closest("form");
      var template = form.querySelector("[data-airview-filter-template]");
      var count = form.querySelectorAll("[data-airview-filter-condition]").length;
      var html = template.innerHTML.replace(/__INDEX__/g, String(count));

      event.target.closest(".airview-filter-actions").insertAdjacentHTML("beforebegin", html);
    }

    if (event.target.matches("[data-airview-remove-filter]")) {
      var filterForm = event.target.closest("form");
      event.target.closest("[data-airview-filter-condition]").remove();
      if (filterForm) filterForm.requestSubmit();
    }

    var filterFieldOption = event.target.closest && event.target.closest("[data-airview-filter-field-option]");
    if (filterFieldOption) {
      selectFilterField(filterFieldOption);
    }

    var referenceResult = event.target.closest && event.target.closest("[data-airview-reference-result]");
    if (referenceResult) {
      selectReferenceResult(referenceResult);
    }

    if (event.target.matches("[data-airview-reference-clear]")) {
      var wrapper = event.target.closest(".airview-reference-picker");
      var hidden = wrapper && wrapper.parentElement.querySelector("[data-airview-reference-target]");
      var input = wrapper && wrapper.querySelector("[data-airview-reference-picker]");
      var results = wrapper && wrapper.querySelector("[data-airview-reference-results]");
      var preview = wrapper && wrapper.parentElement.querySelector("[data-airview-reference-preview]");

      if (hidden) hidden.value = "";
      if (input) input.value = "";
      if (results) results.classList.remove("is-open");
      setReferencePreview(preview, null);

      var clearForm = event.target.closest(".airview-cell-form");
      if (clearForm) clearForm.requestSubmit();
    }

    if (event.target.matches("[data-airview-fields-hide-all], [data-airview-fields-show-all]")) {
      var checked = event.target.matches("[data-airview-fields-show-all]");
      var panel = event.target.closest(".airview-popover-panel");

      Array.prototype.forEach.call(panel.querySelectorAll('input[name="columns[]"]'), function (checkbox) {
        checkbox.checked = checked;
      });
    }

    Array.prototype.forEach.call(document.querySelectorAll(".airview-popover[open]"), function (details) {
      if (!details.contains(event.target)) details.removeAttribute("open");
    });
    Array.prototype.forEach.call(document.querySelectorAll(".airview-column-menu[open]"), function (details) {
      if (!details.contains(event.target)) details.removeAttribute("open");
    });
    Array.prototype.forEach.call(document.querySelectorAll(".airview-view-menu[open]"), function (details) {
      if (!details.contains(event.target)) details.removeAttribute("open");
    });
    Array.prototype.forEach.call(document.querySelectorAll(".airview-reference-results.is-open"), function (results) {
      if (!results.parentElement.contains(event.target)) results.classList.remove("is-open");
    });
    Array.prototype.forEach.call(document.querySelectorAll(".airview-filter-field-results.is-open"), function (results) {
      if (!results.parentElement.contains(event.target)) results.classList.remove("is-open");
    });
  });

  document.addEventListener("change", function (event) {
    if (event.target.matches("[data-airview-modal-field-toggle]")) {
      toggleModalHiddenField(event.target);
      return;
    }

    var form = event.target.closest && event.target.closest(".airview-cell-form");
    if (form) form.requestSubmit();
  });

  document.addEventListener("input", function (event) {
    if (event.target.matches("[data-airview-field-list-search]")) {
      filterFieldList(event.target);
    }

    if (event.target.matches("[data-airview-reference-picker]")) {
      searchReferencePicker(event.target, true);
    }

    if (event.target.matches("[data-airview-filter-field-search]")) {
      searchFilterFieldPicker(event.target);
    }
  });

  document.addEventListener("focusin", function (event) {
    if (event.target.matches("[data-airview-reference-picker]")) {
      searchReferencePicker(event.target, false);
    }

    if (event.target.matches("[data-airview-filter-field-search]")) {
      searchFilterFieldPicker(event.target);
    }
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
      var close = document.querySelector("[data-airview-modal-close]");
      if (close) close.click();
    }

    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      var form = event.target.closest && event.target.closest(".airview-cell-form");
      if (form) {
        event.preventDefault();
        form.requestSubmit();
      }
    }
  });
})();
