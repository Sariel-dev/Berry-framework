const menuRoot = document.getElementById("menu-root");
let currentMenu = null;
let currentPosition = null;
let openPanels = [];

const hideMenu = () => {
  menuRoot.classList.add("is-hidden");
  menuRoot.innerHTML = "";
  currentMenu = null;
  currentPosition = null;
  openPanels = [];
};

const closeContextMenu = () => {
  hideMenu();

  fetch(`https://${GetParentResourceName()}/contextmenu:close`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({})
  }).catch(() => { });
};

const clearPanelsFrom = (index) => {
  while (openPanels.length > index) {
    const panel = openPanels.pop();
    panel.remove();
  }
};

const getBasePosition = (position) => {
  return {
    x: Math.round(window.innerWidth * position.x),
    y: Math.round(window.innerHeight * position.y)
  };
};

const openSubmenu = (submenu, anchorRect, depth) => {
  if (!submenu) return;
  clearPanelsFrom(depth);
  createPanel(submenu, depth, anchorRect);
};

const createPanel = (menu, depth, anchorRect) => {
  const panel = document.createElement("div");
  panel.className = "menu-panel";
  if (depth > 0) panel.classList.add("is-submenu");
  menuRoot.appendChild(panel);

  if (depth === 0 && currentPosition) {
    const base = getBasePosition(currentPosition);
    panel.style.left = `${base.x}px`;
    panel.style.top = `${base.y}px`;
  } else if (anchorRect) {
    panel.style.left = `${anchorRect.right + 2}px`;
    panel.style.top = `${anchorRect.top}px`;
  }

  openPanels.push(panel);

  menu.items.forEach((item) => {
    if (item.type === "separator") {
      const separator = document.createElement("div");
      separator.className = "menu-separator";
      panel.appendChild(separator);
      return;
    }

    if (item.type === "text") {
      const text = document.createElement("div");
      text.className = "menu-item disabled";
      text.textContent = item.title ?? "";
      panel.appendChild(text);
      return;
    }

    const itemRow = document.createElement("div");
    itemRow.className = "menu-item";
    if (!item.enabled) itemRow.classList.add("disabled");

    if (item.icon) {
      const iconWrap = document.createElement("div");
      iconWrap.className = "menu-icon";
      if (typeof item.icon === "string" && item.icon.includes("fa-")) {
        const i = document.createElement("i");
        i.className = item.icon;
        iconWrap.appendChild(i);
      } else {
        iconWrap.textContent = item.icon;
      }
      itemRow.appendChild(iconWrap);
    }

    const title = document.createElement("div");
    title.className = "menu-title";
    title.textContent = item.title ?? "";
    itemRow.appendChild(title);

    if (item.rightText) {
      const right = document.createElement("div");
      right.className = "menu-right";
      right.textContent = item.rightText;
      itemRow.appendChild(right);
    }

    let checkbox = null;
    if (item.type === "checkbox") {
      checkbox = document.createElement("div");
      checkbox.className = "menu-checkbox";
      if (item.checked) checkbox.classList.add("checked");
      checkbox.textContent = item.checked ? "✓" : "";
      itemRow.appendChild(checkbox);
    }

    if (item.type === "submenu") {
      const arrow = document.createElement("div");
      arrow.className = "menu-arrow";
      arrow.innerHTML = '<i class="fa-solid fa-angle-right"></i>';
      itemRow.appendChild(arrow);
    }

    const openSubmenuForRow = () => {
      if (!item.submenu || !item.enabled) return;
      const panelRect = panel.getBoundingClientRect();
      const itemRect = itemRow.getBoundingClientRect();
      openSubmenu(item.submenu, { right: panelRect.right, top: itemRect.top }, depth + 1);
    };

    itemRow.addEventListener("mouseenter", () => {
      if (item.type === "submenu") {
        openSubmenuForRow();
      } else {
        clearPanelsFrom(depth + 1);
      }
    });

    itemRow.addEventListener("click", () => {
      if (!item.enabled) return;
      if (item.type === "submenu") {
        openSubmenuForRow();
        return;
      }

      clearPanelsFrom(depth + 1);

      if (item.type === "checkbox") {
        item.checked = !item.checked;
        if (checkbox) {
          checkbox.classList.toggle("checked", item.checked);
          checkbox.textContent = item.checked ? "✓" : "";
        }
      }

      fetch(`https://${GetParentResourceName()}/contextmenu:select`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: item.id })
      }).catch(() => { });
    });

    panel.appendChild(itemRow);
  });
};

const renderMenu = (menu, position) => {
  if (!menu) return;
  currentMenu = menu;
  currentPosition = position;
  menuRoot.innerHTML = "";
  openPanels = [];
  menuRoot.classList.remove("is-hidden");
  createPanel(menu, 0, null);
};

window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data || !data.action) return;

  if (data.action === "contextmenu:open") {
    renderMenu(data.menu, data.position);
  }

  if (data.action === "contextmenu:close") {
    hideMenu();
  }
});

window.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeContextMenu();
  }
});