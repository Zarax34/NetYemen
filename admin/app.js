(function () {
  'use strict';

  if (!window.NETYEMEN_CONFIG) {
    document.body.innerHTML =
      '<div style="padding:40px;font-family:sans-serif">' +
      '<h2>الإعداد ناقص</h2><p>انسخ <code>config.example.js</code> إلى <code>config.js</code> واملأ عنوان المشروع والمفتاح العام.</p></div>';
    return;
  }

  var cfg = window.NETYEMEN_CONFIG;
  var db = window.supabase.createClient(cfg.url, cfg.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storageKey: 'netyemen-admin-auth'
    }
  });

  // ---------- أدوات UI ----------

  var toastContainer = document.getElementById('toast-container');
  function toast(message, isError) {
    var t = document.createElement('div');
    t.className = 'toast' + (isError ? ' err' : '');
    t.innerHTML = (isError ? '⚠️' : '✅') + ' <span>' + esc(message) + '</span>';
    toastContainer.appendChild(t);
    setTimeout(function() {
      t.classList.add('closing');
      setTimeout(function() { t.remove(); }, 300);
    }, 5000);
  }

  var modalOverlay = document.getElementById('modal-overlay');
  var modalTitle = document.getElementById('modal-title');
  var modalBody = document.getElementById('modal-body');
  var modalFooter = document.getElementById('modal-footer');
  var modalClose = document.getElementById('modal-close');

  function openModal(title, bodyContent, footerHtml) {
    return new Promise(function(resolve) {
      modalTitle.textContent = title;
      if (typeof bodyContent === 'string') {
        modalBody.innerHTML = bodyContent;
      } else {
        modalBody.innerHTML = '';
        modalBody.appendChild(bodyContent);
      }
      modalFooter.innerHTML = footerHtml;
      modalOverlay.classList.add('on');

      var cleanup = function(value) {
        modalOverlay.classList.remove('on');
        modalClose.onclick = null;
        resolve(value);
      };

      modalClose.onclick = function() { cleanup(null); };

      var actions = modalFooter.querySelectorAll('[data-action]');
      for (var i = 0; i < actions.length; i++) {
        actions[i].onclick = function(e) {
          cleanup(e.target.dataset.action);
        };
      }
    });
  }

  function asyncConfirm(message) {
    return openModal('تأكيد', '<p>' + esc(message) + '</p>',
      '<button class="btn btn-ghost" data-action="false">إلغاء</button>' +
      '<button class="btn btn-primary" data-action="true">موافق</button>'
    ).then(function(res) { return res === 'true'; });
  }

  function asyncPrompt(message, type) {
    var div = document.createElement('div');
    div.innerHTML = '<p>' + esc(message) + '</p><input type="' + (type || 'text') + '" id="prompt-input" class="w-full mt-2">';
    return openModal('إدخال', div,
      '<button class="btn btn-ghost" data-action="cancel">إلغاء</button>' +
      '<button class="btn btn-primary" data-action="ok">حفظ</button>'
    ).then(function(res) {
      if (res === 'ok') {
        return document.getElementById('prompt-input').value.trim();
      }
      return null;
    });
  }

  function errText(e) {
    var raw = (e && (e.message || e.error_description)) || String(e);
    var known = {
      UNAUTHENTICATED: 'انتهت الجلسة، سجّل الدخول من جديد',
      FORBIDDEN: 'لا تملك صلاحية لهذا الإجراء',
      NOT_FOUND: 'العنصر غير موجود',
      INVALID_STATE: 'الحالة الحالية لا تسمح بهذا الإجراء'
    };
    for (var key in known) {
      if (raw.indexOf(key) !== -1) return known[key];
    }
    return raw;
  }

  function esc(v) {
    return String(v === null || v === undefined ? '' : v)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function money(n) { return (Number(n) || 0).toLocaleString('en-US'); }
  function when(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    return d.getFullYear() + '/' + (d.getMonth() + 1) + '/' + d.getDate();
  }
  function badge(text, kind) { return '<span class="badge b-' + kind + '">' + esc(text) + '</span>'; }

  var STATUS_STYLE = {
    active: ['نشطة', 'ok'], verified: ['موثّقة', 'ok'], approved: ['مقبول', 'ok'], completed: ['مكتمل', 'ok'], paid: ['مدفوع', 'ok'],
    pending: ['قيد الانتظار', 'warn'], pending_approval: ['بانتظار الموافقة', 'warn'], under_review: ['قيد المراجعة', 'warn'],
    unverified: ['غير موثّقة', 'warn'], draft: ['مسودة', 'mute'], inactive: ['معطّلة', 'mute'], archived: ['مؤرشفة', 'mute'],
    cancelled: ['ملغى', 'mute'], suspended: ['موقوفة', 'err'], rejected: ['مرفوض', 'err'], failed: ['فشل', 'err'], refunded: ['مسترد', 'warn']
  };
  function statusBadge(status) {
    var s = STATUS_STYLE[status] || [status, 'mute'];
    return badge(s[0], s[1]);
  }

  function rpc(name, params) {
    return db.rpc(name, params || {}).then(function (r) {
      if (r.error) throw r.error;
      return r.data;
    });
  }

  function table(headers, rows) {
    if (!rows || !rows.length) return '<div class="empty"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg><p>لا توجد بيانات</p></div>';
    return '<div class="table-wrapper"><table><thead><tr>' +
      headers.map(function (h) { return '<th>' + esc(h) + '</th>'; }).join('') +
      '</tr></thead><tbody>' + rows.join('') + '</tbody></table></div>';
  }

  // ---------- المصادقة ----------

  var loginEl = document.getElementById('login');
  var shellEl = document.getElementById('shell');
  document.getElementById('google-signin').onclick = function () {
    this.disabled = true;
    db.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin }
    })
      .then(function (r) { if (r.error) throw r.error; })
      .catch(function (e) {
        toast(errText(e), true);
        document.getElementById('google-signin').disabled = false;
      });
  };

  document.getElementById('logout').onclick = function () {
    db.auth.signOut().then(function () { location.reload(); });
  };

  function onSignedIn() {
    return rpc('has_platform_role', { p_role: 'platform_admin' }).then(function (isAdmin) {
      if (!isAdmin) {
        toast('هذا الحساب لا يملك صلاحية إدارة', true);
        return db.auth.signOut();
      }
      return db.auth.getUser().then(function (r) {
        document.getElementById('whoami').textContent = (r.data.user && (r.data.user.email || r.data.user.phone)) || '';
        loginEl.style.display = 'none';
        shellEl.classList.add('on');
        route();
      });
    }).catch(function(e) {
      toast(errText(e), true);
      db.auth.signOut();
    });
  }

  // ---------- التوجيه ----------

  var viewEl = document.getElementById('view');
  var views = {};

  var menuToggle = document.getElementById('menu-toggle');
  var sidebar = document.querySelector('.sidebar');
  if(menuToggle && sidebar) {
    menuToggle.onclick = function() { sidebar.classList.toggle('open'); };
  }

  function route() {
    var name = (location.hash || '#dashboard').slice(1);
    if (!views[name]) name = 'dashboard';
    Array.prototype.forEach.call(document.querySelectorAll('.sidebar-nav a'), function (a) {
      a.classList.toggle('active', a.dataset.view === name);
      if (a.dataset.view === name) document.getElementById('page-title').textContent = a.textContent;
    });
    if(sidebar) sidebar.classList.remove('open');
    viewEl.innerHTML = '<div class="empty">جارٍ التحميل…</div>';
    
    Promise.resolve()
      .then(function () { return views[name](); })
      .catch(function (e) {
        viewEl.innerHTML = '<div class="card"><h2>تعذّر التحميل</h2><p class="text-error">' + esc(errText(e)) + '</p></div>';
      });
  }

  window.addEventListener('hashchange', route);

  function bindActionAsync(attr, run, successText) {
    Array.prototype.forEach.call(viewEl.querySelectorAll('[data-' + attr + ']'), function (btn) {
      btn.onclick = function () {
        var p = run(btn.dataset[attr]);
        if (!p || !p.then) return;
        btn.disabled = true;
        p.then(function (res) {
          if (res === false) return; // user cancelled modal
          toast(successText); 
          route(); 
        }).catch(function (e) { toast(errText(e), true); btn.disabled = false; });
      };
    });
  }

  // --- VIEWS ---
  
  views.dashboard = function () {
    return Promise.all([
      rpc('admin_dashboard_kpis').catch(function(){ return {}; }),
      rpc('get_commerce_admin_summary').catch(function(){ return {}; })
    ]).then(function (res) {
      var kpis = res[0] || {};
      var comm = res[1] || {};
      
      var KPI_LABELS = {
        active_networks: 'شبكات نشطة', pending_requests: 'طلبات معلّقة', approved_requests: 'طلبات مقبولة', 
        rejected_requests: 'طلبات مرفوضة', active_packages: 'باقات نشطة', out_of_stock_packages: 'باقات نفد مخزونها', 
        network_owners: 'ملاك شبكات', network_operators: 'مشغّلون'
      };
      
      var COMM_LABELS = {
        total_revenue_yer: 'إجمالي الإيرادات (ر.ي)', total_deposits: 'إجمالي الشحن', pending_settlements: 'تصفيات معلقة',
        total_active_cards: 'كروت نشطة', completed_purchases: 'عمليات ناجحة'
      };

      var kpiCards = Object.keys(KPI_LABELS).map(function (k) {
        if(kpis[k] === undefined) return '';
        return '<div class="kpi"><div class="n">' + money(kpis[k]) + '</div><div class="l">' + esc(KPI_LABELS[k]) + '</div></div>';
      }).join('');
      
      var commCards = Object.keys(COMM_LABELS).map(function (k) {
        if(comm[k] === undefined) return '';
        return '<div class="kpi"><div class="n">' + money(comm[k]) + '</div><div class="l">' + esc(COMM_LABELS[k]) + '</div></div>';
      }).join('');

      viewEl.innerHTML = 
        '<div class="mb-4"><h3>المؤشرات التشغيلية</h3></div><div class="kpis mb-6">' + kpiCards + '</div>' +
        '<div class="mb-4 mt-6"><h3>المؤشرات المالية (Commerce)</h3></div><div class="kpis">' + commCards + '</div>';
    });
  };

  // ---------- الشبكات ----------
  views.networks = function () {
    return db.from('networks').select('*').order('created_at', { ascending: false }).then(function (r) {
      if (r.error) throw r.error;
      var rows = r.data.map(function (n) {
        var actions = '';
        if (n.status !== 'active') actions += '<button class="btn btn-sm btn-accent" data-approve="' + esc(n.id) + '">موافقة</button>';
        if (n.status === 'active') actions += '<button class="btn btn-sm btn-danger" data-suspend="' + esc(n.id) + '">إيقاف</button>';
        return '<tr><td>' + esc(n.commercial_name) + '</td><td>' + esc([n.governorate, n.city, n.district].filter(Boolean).join(' - ')) + '</td><td>' + statusBadge(n.status) + '</td><td>' + statusBadge(n.verification_status) + '</td><td>' + when(n.created_at) + '</td><td class="actions">' + actions + '</td></tr>';
      });
      viewEl.innerHTML = '<div class="card">' +
        '<div class="flex gap-4 mb-4" style="justify-content:space-between; align-items:center;">' +
        '<h3 style="margin:0">الشبكات</h3><button class="btn btn-primary" id="n-add">إنشاء شبكة جديدة</button></div>' +
        table(['الاسم', 'الموقع', 'الحالة', 'التوثيق', 'أُنشئت', 'إجراء'], rows) + '</div>';

      var btnAdd = document.getElementById('n-add');
      if (btnAdd) {
        btnAdd.onclick = function() {
          var div = document.createElement('div');
          div.innerHTML = '<div class="grid grid-1 mb-4" style="gap:10px">' +
            '<div><label>الاسم التجاري <span class="text-error">*</span></label><input id="cn-name"></div>' +
            '<div><label>الوصف</label><input id="cn-desc"></div>' +
            '<div><label>المحافظة</label><input id="cn-gov"></div>' +
            '<div><label>المدينة</label><input id="cn-city"></div>' +
            '<div><label>الحي</label><input id="cn-dist"></div>' +
          '</div>';
          openModal('إنشاء شبكة جديدة', div, '<button class="btn btn-ghost" data-action="cancel">إلغاء</button><button class="btn btn-primary" data-action="ok">حفظ</button>')
            .then(function(res) {
              if (res === 'ok') {
                var name = document.getElementById('cn-name').value.trim();
                if (!name) { toast('الاسم التجاري مطلوب', true); return; }
                var params = {
                  p_commercial_name: name,
                  p_description: document.getElementById('cn-desc').value.trim() || null,
                  p_governorate: document.getElementById('cn-gov').value.trim() || null,
                  p_city: document.getElementById('cn-city').value.trim() || null,
                  p_district: document.getElementById('cn-dist').value.trim() || null
                };
                rpc('create_network_draft', params)
                  .then(function() { toast('تم إنشاء الشبكة بنجاح'); route(); })
                  .catch(function(e) { toast(errText(e), true); });
              }
            });
        };
      }
      
      bindActionAsync('approve', function (id) {
        return asyncConfirm('تأكيد الموافقة على الشبكة وتفعيلها؟').then(function(ok) {
          if(!ok) return false;
          return rpc('admin_approve_network', { p_network_id: id, p_resolution_note: 'موافقة من لوحة الإدارة' });
        });
      }, 'تمت الموافقة');
      bindActionAsync('suspend', function (id) {
        return asyncPrompt('الرجاء إدخال سبب الإيقاف:').then(function(reason) {
          if(!reason) return false;
          return rpc('admin_suspend_network', { p_network_id: id, p_reason: reason });
        });
      }, 'تم إيقاف الشبكة');
    });
  };

  // ---------- SSID توثيق ----------
  views.ssid = function () {
    return db.from('network_ssid_aliases').select('*, networks(commercial_name)').eq('status', 'pending_verification').order('created_at', { ascending: false }).then(function (r) {
      if (r.error) throw r.error;
      var rows = r.data.map(function (a) {
        var actions = '<button class="btn btn-sm btn-accent" data-verify-ssid="' + esc(a.id) + '">توثيق</button>' +
                      '<button class="btn btn-sm btn-danger" data-reject-ssid="' + esc(a.id) + '">رفض</button>';
        return '<tr><td>' + esc(a.ssid) + '</td><td>' + esc(a.networks && a.networks.commercial_name) + '</td><td>' + when(a.created_at) + '</td><td class="actions">' + actions + '</td></tr>';
      });
      viewEl.innerHTML = '<div class="note">قائمة المعرفات (SSID) التي أضافها ملاك الشبكات وتنتظر التوثيق لتظهر للعملاء.</div>' +
                         '<div class="card">' + table(['المعرف (SSID)', 'الشبكة', 'تاريخ الإضافة', 'إجراء'], rows) + '</div>';

      bindActionAsync('verify-ssid', function(id) {
        return asyncConfirm('هل أنت متأكد من توثيق هذا المعرف؟').then(function(ok){
          if(!ok) return false;
          return rpc('admin_verify_ssid_alias', { p_alias_id: id });
        });
      }, 'تم توثيق المعرف');
      bindActionAsync('reject-ssid', function(id) {
        return asyncPrompt('سبب الرفض:').then(function(reason) {
          if(!reason) return false;
          return rpc('admin_reject_ssid_alias', { p_alias_id: id, p_reason: reason });
        });
      }, 'تم رفض المعرف');
    });
  };

  // ---------- الباقات ----------
  views.packages = function () {
    return Promise.all([
      db.from('networks').select('id, commercial_name').order('commercial_name'),
      db.from('network_packages').select('*, networks(commercial_name)').order('created_at', { ascending: false })
    ]).then(function (res) {
      if (res[0].error) throw res[0].error;
      if (res[1].error) throw res[1].error;
      var networks = res[0].data;
      var packages = res[1].data;

      var options = networks.map(function (n) { return '<option value="' + esc(n.id) + '">' + esc(n.commercial_name) + '</option>'; }).join('');
      var rows = packages.map(function (p) {
        var actions = '';
        if (p.status === 'draft' || p.status === 'inactive') actions += '<button class="btn btn-sm btn-accent" data-publish="' + esc(p.id) + '">نشر</button>';
        if (p.status === 'active') actions += '<button class="btn btn-sm btn-ghost" data-deactivate="' + esc(p.id) + '">تعطيل</button>';
        return '<tr><td>' + esc(p.name) + '</td><td>' + esc(p.networks ? p.networks.commercial_name : '') + '</td><td>' + money(p.price) + ' ' + esc(p.currency) + '</td><td>' + esc(p.duration_value ? p.duration_value + ' ' + p.duration_unit : '') + '</td><td>' + statusBadge(p.status) + '</td><td>' + (p.is_public ? badge('معروضة', 'ok') : badge('مخفية', 'mute')) + '</td><td class="actions">' + actions + '</td></tr>';
      });

      viewEl.innerHTML = (networks.length ? '' : '<div class="note">أضف شبكة أولاً — الباقة تتبع شبكة.</div>') +
        '<div class="card"><div class="card-header"><h3>إضافة باقة</h3></div>' +
          '<div class="grid grid-3 mb-4">' +
            '<div><label>الشبكة</label><select id="p-network">' + options + '</select></div>' +
            '<div><label>الاسم</label><input id="p-name" placeholder="باقة شهرية"></div>' +
            '<div><label>السعر (ر.ي)</label><input id="p-price" type="number" min="1"></div>' +
            '<div><label>النوع</label><select id="p-type"><option value="time">زمنية</option><option value="data">بيانات</option><option value="hybrid">مختلطة</option></select></div>' +
            '<div><label>مدة الصلاحية</label><input id="p-dur" type="number" min="1"></div>' +
            '<div><label>وحدة المدة</label><select id="p-unit"><option value="day">يوم</option><option value="hour">ساعة</option><option value="week">أسبوع</option><option value="month">شهر</option></select></div>' +
            '<div><label>السرعة (ميجابت/ث)</label><input id="p-speed" type="number" min="1"></div>' +
          '</div>' +
          '<label>الوصف</label><textarea id="p-desc" rows="2" class="mb-4"></textarea>' +
          '<button class="btn btn-primary" id="p-create"' + (networks.length ? '' : ' disabled') + '>إنشاء</button>' +
        '</div>' +
        '<div class="card"><div class="card-header"><h3>الباقات الحالية</h3></div>' + table(['الباقة', 'الشبكة', 'السعر', 'المدة', 'الحالة', 'العرض', ''], rows) + '</div>';

      var btnCreate = document.getElementById('p-create');
      if (btnCreate) btnCreate.onclick = function () {
        var name = document.getElementById('p-name').value.trim();
        var price = parseInt(document.getElementById('p-price').value, 10);
        if (!name) return toast('أدخل اسم الباقة', true);
        if (!price || price < 1) return toast('أدخل سعراً صحيحاً', true);
        this.disabled = true;
        var dur = parseInt(document.getElementById('p-dur').value, 10);
        var speed = parseInt(document.getElementById('p-speed').value, 10);
        rpc('create_network_package', {
          p_network_id: document.getElementById('p-network').value,
          p_name: name, p_description: document.getElementById('p-desc').value.trim() || null,
          p_price: price, p_currency: 'YER',
          p_duration_value: isNaN(dur) ? null : dur, p_duration_unit: isNaN(dur) ? null : document.getElementById('p-unit').value,
          p_speed_mbps: isNaN(speed) ? null : speed, p_package_type: document.getElementById('p-type').value
        }).then(function () { toast('تم إنشاء الباقة'); route(); }).catch(function (e) { toast(errText(e), true); }).finally(function () { if(btnCreate) btnCreate.disabled = false; });
      };

      bindActionAsync('publish', function (id) { return rpc('publish_network_package', { p_package_id: id }); }, 'تم نشر الباقة');
      bindActionAsync('deactivate', function (id) { return rpc('deactivate_network_package', { p_package_id: id }); }, 'تم تعطيل الباقة');
    });
  };

  // ---------- المستخدمون والأدوار ----------
  var ROLE_LABELS = { customer: 'عميل', network_owner: 'مالك شبكة', network_operator: 'مشغّل', platform_admin: 'مدير المنصة', finance_officer: 'موظف مالية', support_agent: 'دعم فني' };
  views.users = function () {
    return Promise.all([
      db.from('profiles').select('*').order('created_at', { ascending: false }),
      db.from('user_roles').select('user_id, role'),
      rpc('admin_list_access_grants').catch(function () { return []; })
    ]).then(function (res) {
      if (res[0].error) throw res[0].error;
      if (res[1].error) throw res[1].error;
      var grants = res[2] || [];
      var rolesByUser = {};
      res[1].data.forEach(function (r) { (rolesByUser[r.user_id] = rolesByUser[r.user_id] || []).push(r.role); });

      var rows = res[0].data.map(function (p) {
        var roles = (rolesByUser[p.id] || []).map(function (r) { return badge(ROLE_LABELS[r] || r, r === 'platform_admin' ? 'ok' : 'mute'); }).join(' ');
        var toggle = p.account_status === 'active'
          ? '<button class="btn btn-sm btn-danger" data-suspend-user="' + esc(p.id) + '">إيقاف</button>'
          : '<button class="btn btn-sm btn-accent" data-activate-user="' + esc(p.id) + '">تفعيل</button>';
        return '<tr><td>' + esc(p.full_name || '—') + '</td><td class="text-sm text-muted" dir="ltr">' + esc(p.id) + '</td><td>' + roles + '</td><td>' + statusBadge(p.account_status) + '</td><td>' + when(p.created_at) + '</td><td class="actions">' + toggle + '<button class="btn btn-sm btn-ghost" data-role-user="' + esc(p.id) + '">الأدوار</button></td></tr>';
      });

      var GRANTABLE = [
        ['network_owner', 'مالك شبكة'], ['network_operator', 'مشغّل شبكة'],
        ['finance_officer', 'موظف مالية'], ['support_agent', 'دعم'], ['platform_admin', 'مدير منصة']
      ];
      var roleChecks = GRANTABLE.map(function (g) {
        return '<label class="chk"><input type="checkbox" class="inv-role" value="' + g[0] + '"> ' + esc(g[1]) + '</label>';
      }).join(' ');
      var grantRows = (grants || []).map(function (g) {
        var st = g.applied_at ? badge('مُفعّلة', 'ok') : badge('بانتظار الدخول', 'warn');
        var rolesTxt = (g.roles || []).map(function (r) { return ROLE_LABELS[r] || r; }).join('، ');
        var act = g.applied_at ? '' : '<button class="btn btn-sm btn-danger" data-revoke-grant="' + esc(g.id) + '">إلغاء</button>';
        return '<tr><td dir="ltr">' + esc(g.email) + '</td><td>' + esc(rolesTxt) + '</td><td>' + st + '</td><td>' + when(g.created_at) + '</td><td class="actions">' + act + '</td></tr>';
      });

      viewEl.innerHTML =
        '<div class="card"><div class="card-header"><h3>إضافة مستخدم (دعوة بالبريد)</h3></div>' +
          '<div class="note">أدخل بريد الشخص واختر دوره. عند تسجيله الدخول عبر Google بنفس البريد يُمنح الدور تلقائياً — وإن كان مسجّلاً بالفعل يُطبّق فوراً.</div>' +
          '<div class="grid grid-2 mb-4">' +
            '<div><label>البريد الإلكتروني</label><input id="inv-email" type="email" placeholder="name@gmail.com" dir="ltr"></div>' +
            '<div><label>ملاحظة (اختياري)</label><input id="inv-note" type="text" placeholder="مثال: مالك شبكة النور"></div>' +
          '</div>' +
          '<div class="mb-4"><label>الأدوار</label><div class="flex gap-4 flex-wrap">' + roleChecks + '</div></div>' +
          '<button class="btn btn-primary" id="inv-submit">إرسال الدعوة</button>' +
          (grantRows.length ? '<div class="mt-4">' + table(['البريد', 'الأدوار', 'الحالة', 'أُنشئت', 'إجراء'], grantRows) + '</div>' : '') +
        '</div>' +
        '<div class="card">' + table(['الاسم', 'المعرّف', 'الأدوار', 'الحالة', 'انضم', 'إجراء'], rows) + '</div>';

      document.getElementById('inv-submit').onclick = function () {
        var email = document.getElementById('inv-email').value.trim();
        var note = document.getElementById('inv-note').value.trim();
        var roles = Array.prototype.map.call(document.querySelectorAll('.inv-role:checked'), function (c) { return c.value; });
        if (!email) return toast('أدخل البريد الإلكتروني', true);
        if (!roles.length) return toast('اختر دوراً واحداً على الأقل', true);
        var btn = this; btn.disabled = true;
        rpc('admin_create_access_grant', { p_email: email, p_roles: roles, p_note: note || null })
          .then(function () { toast('تمت إضافة الدعوة'); route(); })
          .catch(function (e) { toast(errText(e), true); btn.disabled = false; });
      };
      bindActionAsync('revoke-grant', function (id) {
        return rpc('admin_revoke_access_grant', { p_id: id });
      }, 'أُلغيت الدعوة');

      bindActionAsync('suspend-user', function (id) {
        return asyncPrompt('سبب الإيقاف؟').then(function(reason) {
          if(!reason) return false;
          return rpc('admin_set_user_account_status', { p_user_id: id, p_status: 'suspended', p_reason: reason });
        });
      }, 'تم إيقاف الحساب');
      bindActionAsync('activate-user', function (id) {
        return rpc('admin_set_user_account_status', { p_user_id: id, p_status: 'active', p_reason: 'إعادة تفعيل' });
      }, 'تم تفعيل الحساب');
      bindActionAsync('role-user', function (id) {
        var div = document.createElement('div');
        div.innerHTML = '<p>اختر الدور الذي ترغب في إدارته لهذا المستخدم:</p>' +
          '<select id="role-select" class="mb-4"><option value="network_owner">مالك شبكة</option><option value="platform_admin">مدير منصة</option><option value="finance_officer">موظف مالية</option></select>' +
          '<div class="flex gap-4"><label><input type="radio" name="role-act" value="grant" checked> منح الدور</label><label><input type="radio" name="role-act" value="revoke"> سحب الدور</label></div>';
        return openModal('إدارة الأدوار', div, '<button class="btn btn-ghost" data-action="cancel">إلغاء</button><button class="btn btn-primary" data-action="ok">حفظ</button>').then(function(res) {
          if(res === 'ok') {
            var role = document.getElementById('role-select').value;
            var enable = document.querySelector('input[name="role-act"]:checked').value === 'grant';
            return rpc('admin_set_user_platform_role', { p_user_id: id, p_role: role, p_enabled: enable });
          }
          return false;
        });
      }, 'تم تحديث الأدوار');
    });
  };

  // ---------- وجهات الدفع ----------
  views.destinations = function () {
    return rpc('admin_get_payment_destinations').then(function (list) {
      var rows = (list || []).map(function (d) {
        var toggle = d.is_active
          ? '<button class="btn btn-sm btn-ghost" data-deact="' + esc(d.id) + '">تعطيل</button>'
          : '<button class="btn btn-sm btn-accent" data-act="' + esc(d.id) + '">تفعيل</button>';
        return '<tr><td>' + esc(d.display_name) + '</td><td>' + esc(d.provider_type) + '</td><td>' + esc(d.account_holder_name) + '</td><td dir="ltr" class="text-center">' + esc(d.account_identifier) + '</td><td>' + (d.is_active ? badge('مفعّلة', 'ok') : badge('معطّلة', 'mute')) + '</td><td class="actions">' + toggle + '</td></tr>';
      });

      viewEl.innerHTML = '<div class="note">هذه الوجهات تظهر للعميل في شاشة شحن المحفظة.</div>' +
        '<div class="card"><div class="card-header"><h3>إضافة وجهة دفع جديدة</h3></div>' +
          '<div class="grid grid-2 mb-4">' +
            '<div><label>النوع</label><select id="d-type"><option value="bank_account">حساب بنكي</option><option value="mobile_wallet">محفظة إلكترونية</option><option value="exchange">صرافة</option></select></div>' +
            '<div><label>الاسم المعروض</label><input id="d-name" placeholder="بنك الكريمي"></div>' +
            '<div><label>اسم صاحب الحساب</label><input id="d-holder"></div>' +
            '<div><label>رقم الحساب</label><input id="d-acct" dir="ltr"></div>' +
          '</div>' +
          '<label>تعليمات إضافية للعميل</label><textarea id="d-inst" rows="2" class="mb-4"></textarea>' +
          '<button class="btn btn-primary" id="d-create">إضافة الوجهة</button>' +
        '</div>' +
        '<div class="card"><div class="card-header"><h3>وجهات الدفع الحالية</h3></div>' + table(['الاسم', 'النوع', 'صاحب الحساب', 'رقم الحساب', 'الحالة', 'إجراء'], rows) + '</div>';

      var btnCreate = document.getElementById('d-create');
      if (btnCreate) btnCreate.onclick = function () {
        var name = document.getElementById('d-name').value.trim();
        if (!name) return toast('أدخل الاسم المعروض', true);
        this.disabled = true;
        rpc('admin_create_payment_destination', {
          p_provider_type: document.getElementById('d-type').value,
          p_display_name: name,
          p_account_holder_name: document.getElementById('d-holder').value.trim() || null,
          p_account_identifier: document.getElementById('d-acct').value.trim() || null,
          p_instructions: document.getElementById('d-inst').value.trim() || null,
          p_currency: 'YER', p_sort_order: 0
        }).then(function () { toast('تمت الإضافة'); route(); }).catch(function (e) { toast(errText(e), true); }).finally(function () { if(btnCreate) btnCreate.disabled = false; });
      };

      bindActionAsync('act', function (id) { return rpc('admin_set_payment_destination_active', { p_id: id, p_active: true }); }, 'تم التفعيل');
      bindActionAsync('deact', function (id) { return rpc('admin_set_payment_destination_active', { p_id: id, p_active: false }); }, 'تم التعطيل');
    });
  };

  // ---------- طلبات الشحن ----------
  views.deposits = function () {
    var status = sessionStorage.getItem('depositFilter') || 'pending';
    return rpc('get_finance_deposit_queue', { p_status: status }).then(function (list) {
      var rows = (list || []).map(function (d) {
        var actions = '';
        if (d.status === 'pending' || d.status === 'under_review') {
          actions = '<button class="btn btn-sm btn-accent" data-approve-dep="' + esc(d.id) + '">قبول</button>' +
                    '<button class="btn btn-sm btn-danger" data-reject-dep="' + esc(d.id) + '">رفض</button>';
        }
        return '<tr><td>' + money(d.amount) + ' ر.ي</td><td dir="ltr" class="text-center">' + esc(d.reference_number) + '</td><td>' + statusBadge(d.status) + '</td><td>' + when(d.created_at) + '</td><td class="actions">' + actions + '</td></tr>';
      });

      var filters = ['pending', 'under_review', 'approved', 'rejected', 'cancelled'].map(function (s) {
        var label = (STATUS_STYLE[s] || [s])[0];
        return '<button class="btn btn-sm ' + (s === status ? 'btn-primary' : 'btn-ghost') + '" data-filter="' + s + '">' + esc(label) + '</button>';
      }).join('');

      viewEl.innerHTML = '<div class="card"><div class="flex gap-2">' + filters + '</div></div>' +
        '<div class="card">' + table(['المبلغ', 'رقم الحوالة/المرجع', 'الحالة', 'التاريخ', 'إجراء'], rows) + '</div>';

      Array.prototype.forEach.call(viewEl.querySelectorAll('[data-filter]'), function (btn) {
        btn.onclick = function () { sessionStorage.setItem('depositFilter', btn.dataset.filter); route(); };
      });

      bindActionAsync('approve-dep', function (id) {
        return asyncConfirm('تأكيد قبول الطلب وإيداع المبلغ في محفظة العميل فوراً؟').then(function(ok) {
          if(!ok) return false;
          return rpc('review_wallet_deposit_request', { p_deposit_id: id, p_action: 'approve', p_rejection_reason: null });
        });
      }, 'تم قبول الطلب وإضافة الرصيد');

      bindActionAsync('reject-dep', function (id) {
        return asyncPrompt('سبب الرفض:').then(function(reason) {
          if(!reason) return false;
          return rpc('review_wallet_deposit_request', { p_deposit_id: id, p_action: 'reject', p_rejection_reason: reason });
        });
      }, 'تم رفض الطلب');
    });
  };

  // ---------- تصفية المستحقات ----------
  views.settlements = function () {
    var status = sessionStorage.getItem('settlementFilter') || 'pending_approval';
    return Promise.all([
      db.from('networks').select('id, commercial_name').order('commercial_name'),
      rpc('get_finance_settlement_batches', { p_status: status }).catch(function(){ return []; })
    ]).then(function (res) {
      if (res[0].error) throw res[0].error;
      var networks = res[0].data;
      var list = res[1] || [];

      var rows = list.map(function (b) {
        var actions = '';
        if (b.status === 'pending_approval') actions += '<button class="btn btn-sm btn-accent" data-approve-set="' + esc(b.id) + '">موافقة</button>';
        if (b.status === 'approved') actions += '<button class="btn btn-sm btn-primary" data-pay-set="' + esc(b.id) + '">سداد</button>';
        
        return '<tr><td>' + esc(b.networks && b.networks.commercial_name) + '</td><td>' + when(b.period_start) + ' - ' + when(b.period_end) + '</td><td>' + money(b.total_amount) + '</td><td>' + money(b.commission_amount) + '</td><td>' + money(b.net_amount) + '</td><td>' + statusBadge(b.status) + '</td><td class="actions">' + actions + '</td></tr>';
      });

      var filters = ['pending_approval', 'approved', 'paid'].map(function (s) {
        var label = (STATUS_STYLE[s] || [s])[0];
        return '<button class="btn btn-sm ' + (s === status ? 'btn-primary' : 'btn-ghost') + '" data-filter="' + s + '">' + esc(label) + '</button>';
      }).join('');
      
      var options = '<option value="">الكل (أو اختر شبكة)</option>' + networks.map(function (n) { return '<option value="' + esc(n.id) + '">' + esc(n.commercial_name) + '</option>'; }).join('');

      viewEl.innerHTML = '<div class="card"><div class="card-header"><h3>إنشاء دفعة تصفية</h3></div>' +
        '<div class="grid grid-3 mb-4">' +
          '<div><label>من تاريخ</label><input type="date" id="s-start"></div>' +
          '<div><label>إلى تاريخ</label><input type="date" id="s-end"></div>' +
          '<div><label>الشبكة (اختياري)</label><select id="s-network">' + options + '</select></div>' +
        '</div>' +
        '<button class="btn btn-primary" id="s-create">إنشاء الدفعة</button></div>' +
        '<div class="card"><div class="flex gap-2">' + filters + '</div></div>' +
        '<div class="card"><div class="card-header"><h3>دفعات التصفية</h3></div>' + table(['الشبكة', 'الفترة', 'الإجمالي', 'العمولة', 'الصافي', 'الحالة', 'إجراء'], rows) + '</div>';

      Array.prototype.forEach.call(viewEl.querySelectorAll('[data-filter]'), function (btn) {
        btn.onclick = function () { sessionStorage.setItem('settlementFilter', btn.dataset.filter); route(); };
      });

      var btnCreate = document.getElementById('s-create');
      if (btnCreate) btnCreate.onclick = function () {
        var start = document.getElementById('s-start').value;
        var end = document.getElementById('s-end').value;
        var nid = document.getElementById('s-network').value || null;
        if (!start || !end) return toast('حدد تاريخ البداية والنهاية', true);
        this.disabled = true;
        rpc('finance_create_settlement_batch', { p_period_start: start, p_period_end: end, p_network_id: nid })
          .then(function () { toast('تم إنشاء الدفعة'); route(); }).catch(function (e) { toast(errText(e), true); }).finally(function () { if(btnCreate) btnCreate.disabled = false; });
      };

      bindActionAsync('approve-set', function (id) {
        return asyncConfirm('تأكيد الموافقة على الدفعة؟').then(function(ok) {
          if(!ok) return false;
          return rpc('finance_approve_settlement_batch', { p_batch_id: id });
        });
      }, 'تمت الموافقة');

      bindActionAsync('pay-set', function (id) {
        return asyncPrompt('ملاحظات السداد (مثال: رقم التحويل):').then(function(notes) {
          if(notes === null) return false;
          return rpc('finance_mark_settlement_paid', { p_batch_id: id, p_notes: notes });
        });
      }, 'تم السداد');
    });
  };

  // ---------- الإشعارات ----------
  views.notifications = function () {
    return rpc('get_notification_transport_status').catch(function(){ return []; }).then(function(statusList) {
      var transportRows = (statusList || []).map(function(s) {
        return '<tr><td>' + esc(s.transport_type) + '</td><td>' + (s.is_active ? badge('نشط', 'ok') : badge('متوقف', 'err')) + '</td><td>' + esc(s.pending_count) + '</td><td>' + esc(s.failed_count) + '</td></tr>';
      });

      viewEl.innerHTML = '<div class="card"><div class="card-header"><h3>إرسال إشعار جديد</h3></div>' +
        '<div class="grid grid-2 mb-4">' +
          '<div><label>العنوان</label><input id="n-title" placeholder="عرض جديد!"></div>' +
          '<div><label>نوع الجمهور</label><select id="n-audience"><option value="all">الكل</option><option value="customers">العملاء فقط</option><option value="network_owners">ملاك الشبكات</option></select></div>' +
          '<div><label>القناة</label><select id="n-channel"><option value="push">تنبيه (Push)</option><option value="sms">رسالة نصية (SMS)</option></select></div>' +
          '<div><label>رابط عميق (Deep Link)</label><input id="n-link" placeholder="/offers"></div>' +
        '</div>' +
        '<label>النص</label><textarea id="n-body" rows="3" class="mb-4"></textarea>' +
        '<div class="flex items-center gap-2 mb-4"><input type="checkbox" id="n-imm" checked> <label style="margin:0">إرسال فوراً</label></div>' +
        '<button class="btn btn-primary" id="n-send">إرسال الإشعار</button></div>' +
        '<div class="card"><div class="card-header"><h3>حالة نواقل الإشعارات</h3></div>' + table(['الناقل', 'الحالة', 'في الانتظار', 'فشلت'], transportRows) + '</div>';

      var btnSend = document.getElementById('n-send');
      if (btnSend) btnSend.onclick = function() {
        var title = document.getElementById('n-title').value.trim();
        var body = document.getElementById('n-body').value.trim();
        if(!title || !body) return toast('أدخل العنوان والنص', true);
        this.disabled = true;
        rpc('admin_compose_notification', {
          p_title_ar: title, p_body_ar: body,
          p_audience_type: document.getElementById('n-audience').value,
          p_audience_payload: {},
          p_channel_class: document.getElementById('n-channel').value,
          p_deep_link: document.getElementById('n-link').value.trim() || null,
          p_scheduled_for: null, p_idempotency_key: null,
          p_process_immediately: document.getElementById('n-imm').checked
        }).then(function() { toast('تمت جدولة الإشعار'); route(); }).catch(function(e) { toast(errText(e), true); }).finally(function() { if(btnSend) btnSend.disabled = false; });
      };
    });
  };

  // ---------- إعدادات العمولة ----------
  views.commission = function () {
    viewEl.innerHTML = '<div class="card"><div class="card-header"><h3>العمولة الافتراضية</h3></div>' +
      '<p class="mb-4 text-muted">تُخصم هذه العمولة من مبيعات الشبكات تلقائياً (كنسبة مئوية).</p>' +
      '<div style="max-width:300px"><label>نسبة العمولة (%)</label><input type="number" id="c-rate" step="0.1" min="0" max="100" class="mb-4"></div>' +
      '<button class="btn btn-primary" id="c-save">تحديث العمولة</button></div>';
      
    var btnSave = document.getElementById('c-save');
    if (btnSave) btnSave.onclick = function() {
      var rate = parseFloat(document.getElementById('c-rate').value);
      if(isNaN(rate) || rate < 0 || rate > 100) return toast('أدخل نسبة صحيحة بين 0 و 100', true);
      this.disabled = true;
      rpc('admin_update_default_commission_rate', { p_rate: rate })
        .then(function() { toast('تم التحديث بنجاح'); }).catch(function(e) { toast(errText(e), true); }).finally(function() { if(btnSave) btnSave.disabled = false; });
    };
  };

  // ---------- خزنة الكروت ----------
  views.cards = function () {
    return Promise.all([
      db.from('networks').select('id, commercial_name').order('commercial_name'),
      db.from('network_packages').select('id, network_id, name').order('name')
    ]).then(function (res) {
      if (res[0].error) throw res[0].error;
      if (res[1].error) throw res[1].error;
      var networks = res[0].data;
      var packages = res[1].data;

      var options = networks.map(function (n) { return '<option value="' + esc(n.id) + '">' + esc(n.commercial_name) + '</option>'; }).join('');
      viewEl.innerHTML = '<div class="card"><div class="card-header"><h3>رفع دفعة كروت</h3></div>' +
        '<div class="grid grid-2 mb-4">' +
          '<div><label>الشبكة</label><select id="c-up-network">' + options + '</select></div>' +
          '<div><label>الباقة</label><select id="c-up-package"></select></div>' +
        '</div>' +
        '<label>تاريخ الانتهاء (اختياري)</label><input type="date" id="c-up-expires" class="mb-4">' +
        '<label>أرقام الكروت (PINs) — رقم في كل سطر</label><textarea id="c-up-pins" rows="5" class="mb-4" dir="ltr" style="text-align:left"></textarea>' +
        '<button class="btn btn-primary" id="c-upload">رفع الكروت</button></div>' +
        '<div class="card"><div class="card-header"><h3>الكروت الحالية (البيانات الوصفية)</h3></div>' +
        '<div class="flex gap-4 mb-4"><div style="flex:1"><label style="margin:0">الشبكة</label><select id="c-network">' + options + '</select></div>' +
        '<button class="btn btn-ghost" id="c-load" style="margin-top:20px">عرض</button></div>' +
        '<div id="c-result"></div></div>';

      var packagesByNetwork = {};
      packages.forEach(function(p) { (packagesByNetwork[p.network_id] = packagesByNetwork[p.network_id] || []).push(p); });

      var netSelect = document.getElementById('c-up-network');
      var pkgSelect = document.getElementById('c-up-package');
      function filterPackages() {
        var nid = netSelect.value;
        pkgSelect.innerHTML = (packagesByNetwork[nid] || []).map(function(p) { return '<option value="' + esc(p.id) + '">' + esc(p.name) + '</option>'; }).join('');
      }
      if (netSelect) { netSelect.onchange = filterPackages; filterPackages(); }

      var btnUpload = document.getElementById('c-upload');
      if (btnUpload) btnUpload.onclick = function () {
        var nid = netSelect.value;
        var pid = pkgSelect.value;
        var expires = document.getElementById('c-up-expires').value;
        if (!nid || !pid) return toast('اختر الشبكة والباقة', true);
        var pins = document.getElementById('c-up-pins').value.split('\n').map(function(s) { return s.trim(); }).filter(Boolean);
        if (!pins.length) return toast('أدخل كرت واحد على الأقل', true);
        var p_cards = pins.map(function(pin) { return { pin: pin, expires_at: expires || null }; });
        
        btnUpload.disabled = true;
        rpc('admin_ingest_card_vault_batch', { p_network_id: nid, p_package_id: pid, p_cards: p_cards })
          .then(function (r) { 
            toast('تم رفع ' + r.ingested_count + ' كرت بنجاح');
            document.getElementById('c-up-pins').value = '';
          }).catch(function (e) { toast(errText(e), true); }).finally(function () { btnUpload.disabled = false; });
      };

      var btnLoad = document.getElementById('c-load');
      if (btnLoad) btnLoad.onclick = function () {
        var nid = document.getElementById('c-network').value;
        if (!nid) return;
        btnLoad.disabled = true;
        rpc('admin_list_card_vault_metadata', { p_network_id: nid, p_state: null })
          .then(function (list) {
            var rows = (list || []).map(function (c) {
              return '<tr><td dir="ltr" class="text-sm">' + esc(c.batch_id) + '</td><td>' + esc(c.state) + '</td><td>' + when(c.created_at) + '</td><td>' + when(c.expires_at) + '</td></tr>';
            });
            document.getElementById('c-result').innerHTML = table(['الدفعة', 'الحالة', 'أُضيف', 'ينتهي'], rows);
          }).catch(function (e) { toast(errText(e), true); }).finally(function () { btnLoad.disabled = false; });
      };
    });
  };

  // الإقلاع
  db.auth.getSession().then(function (r) {
    if (r.data.session) return onSignedIn();
  }).catch(function () {});
})();
