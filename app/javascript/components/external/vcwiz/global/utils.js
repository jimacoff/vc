import React from 'react';
import axios from 'axios';
import parseDomain from 'parse-domain';
import { LocalStorage, SessionStorage } from './storage.js.erb';
import {
  FounderEventNames, FounderEventPath, StorageRestoreStateKey,
  MobileScreenSize, SortDirection,
} from './constants.js.erb';
import Breadcrumb from './breadcrumbs';
import { canUseDOM } from 'exenv';
import {SortDirection as TableSortDirection} from 'react-virtualized';

axios.interceptors.response.use(undefined, err => {
  if (err.status === 503 && err.config && !err.config.__isRetryRequest) {
    err.config.__isRetryRequest = true;
    return axios(err.config);
  }
  throw err;
});

const __fetch = (path, opts) => axios({url: path, ...opts}).then(resp => resp.data).catch(e => Raven.captureException(e));

export const _ffetch = function(path, data, opts) {
  if (opts.form) {
    delete opts.form;
    let formData = new FormData();
    Object.entries(data || {}).forEach(([k, v]) => {
      formData.append(k, v);
    });
    opts.data = formData;
  } else if (data) {
    opts.data = JSON.stringify(data);
    opts.headers['Content-Type'] = 'application/json';
  } else if (opts.method === 'GET' && opts.cache) {
    delete opts.cache;
    const Storage = opts.session ? SessionStorage : LocalStorage;
    delete opts.session;
    const cached = Storage.getExpr(path);
    if (cached) {
      return new Promise(cb => cb(cached));
    } else {
      return __fetch(path, opts).then(res => {
        Storage.setExpr(path, res, 3600);
        return res;
      });
    }
  }

  return __fetch(path, opts);
};

export const ffetch = function(path, method = 'GET', data = null, opts = {}) {
  const allOpts = {
    ...opts,
    headers: {
      'X-CSRF-Token': csrfToken(),
    },
    method,
  };
  return _ffetch(path, data, allOpts);
};

export const ffetchCached = function(path, session = false) {
  return ffetch(path, 'GET', null, {cache: true, session});
};

export const flush = function() {
  setTimeout(() => {
    LocalStorage.clearExpr();
    SessionStorage.clearExpr();
  }, 0);
};

export const csrfToken = function() {
  return window.gon.csrfToken;
};

export const isLoggedIn = function() {
  return !!(window.gon && window.gon.founder);
};

export const fullName = function(founder) {
  return `${founder.first_name} ${founder.last_name}`;
};

export const initials = function(founder) {
  return `${_.first(founder.first_name) || ''}${_.first(founder.last_name) || ''}`;
};

export const firstName = function(name) {
  return _.first(name.split(' '));
};

let _extend = function(dest, src, overwrite = true) {
  let ret = Object.assign({}, dest);
  Object.entries(src).forEach(([k, v]) => {
    if (v !== undefined && (overwrite || _.isEmpty(ret[k]))) {
      ret[k] = v;
    }
  });
  return ret;
};

export const extend = (dest, src) => _extend(dest, src, true);
export const merge = (dest, src) => _extend(dest, src, false);

export const buildQuery = (row, context = '') => {
  const keys = Object.keys(row);
  keys.sort();
  return _.compact(_.map(keys, k => {
    let val = _.get(row, k);
    if (_.isObjectLike(val)) {
      return buildQuery(val, k);
    }
    if (nullOrUndef(val) || val === "" || val === 0) {
      return null;
    } else if (context) {
      return `${context}[${k}]=${val}`;
    } else {
      return `${k}=${val}`;
    }
  })).join('&')
};

export const nullOrUndef = (val) => val === undefined || val === null;

export const getDomain = (url, withSubdomain = true) => {
  if (!url) {
    return null;
  }
  let parts;
  try {
    parts = parseDomain(url);
  } catch (err) {
    parts = null;
  }
  if (!parts || _.isEmpty(parts)) {
    return null;
  } else {
    return _.compact([withSubdomain && (parts.subdomain !== 'wwww') ? parts.subdomain : null, parts.domain, parts.tld]).join('.');
  }
};

export const timestamp = () => Date.now();
export const flattenFilters = filters => _.pickBy(_.mapValues(filters, f => _.uniq(_.map(f, 'value')).join(',')), Boolean);
export const withSeparators = (sepFn, a) => _.flatMap(_.zip(a, _.times(a.length - 1, sepFn)));
export const withDots = a => withSeparators(i => <span key={`dot-${i}`} className="dot">·</span>, a);

export const imageExists = url => {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = resolve;
    img.onerror = reject;
    img.src = url;
  });
};

export const currentPage = () => {
  return window.location.pathname + window.location.search;
};

export const replaceSort = (key, direction, oldSort) => {
  const keys = Object.keys(oldSort);
  const base = _.zipObject(keys, _.times(keys.length, _.constant(0)));
  return extend(base, {[key]: direction});
};

export const sendEvent = (name, ...args) => {
  if (!isLoggedIn()) {
    return;
  }
  if (_.includes(FounderEventNames, name)) {
    return ffetch(FounderEventPath, 'POST', {event: {name, args}});
  } else {
    if (canUseDOM && window.mixpanel) {
      mixpanel.track(name, {args});
    }
  }
};

export const withoutIndexes = (arr, idxs) => {
  const newArr = [...arr];
  _.pullAt(newArr, idxs);
  return newArr;
};

const filterOptionMatches = (value, filterValue) => value.toLowerCase().indexOf(filterValue) >= 0;

export const filterOption = (option, filterValue) => {
  if (!filterValue) return true;
  const value = String(option.value);
  const label = String(option.label);
  const otherLabels = option.other_labels;
  return (
    filterOptionMatches(value, filterValue) ||
    filterOptionMatches(label, filterValue) ||
    (otherLabels && _.some(otherLabels, ov => filterOptionMatches(ov, filterValue)))
  );
};

export const humanizeList = list => {
  if (list.length === 1) {
    return _.first(list);
  } else if (list.length === 2) {
    return [<span key="first">{_.first(list)}</span>, <span key="and"> and </span>, <span key="last">{_.last(list)}</span>];
  } else {
    const initial = _.flatMap(_.initial(list), (s, i) => [<span key={`s-${i}`}>{s}</span>, <span key={`comma-${i}`}>, </span>]);
    return initial.concat([<span key="and"> and </span>, <span key="last">{_.last(list)}</span>]);
  }
};

export const humanizeTravelStatus = (travelStatus, openCity) => {
  switch (travelStatus) {
    case 'working':
      return `hard at work${openCity ? ` in ${openCity}` : ''}`;
    case 'work_traveling':
      return `travelling for work${openCity ? ` in ${openCity}` : ''}`;
    case 'pleasure_traveling':
      return `taking a vacation${openCity ? ` in ${openCity}` : ''}`;
  }
};

export const saveCurrentRestoreState = () => {
  SessionStorage.set(StorageRestoreStateKey, {
    breadcrumb: Breadcrumb.peek(),
    location: currentPage(),
  });
};

export const toOptions = (arr, options) => arr.map(x => ({value: x, label: options[x]}));
export const screenWidth = () => window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth;
export const screenHeight = () => window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;
export const isMobile = () => canUseDOM && screenWidth() <= MobileScreenSize;

export const preloadImage = path => {
  const preload = document.createElement("link");
  preload.href = path;
  preload.rel = 'preload';
  preload.as = 'image';
  document.head.appendChild(preload);
};
export const preloadImages = images => images.forEach(preloadImage);

export const doNotPropagate = e => {
  e.preventDefault();
  e.stopPropagation();
  return false;
};

export const fromTableSD = sd => {
  switch (sd) {
    case TableSortDirection.ASC:
      return SortDirection.Asc;
    case TableSortDirection.DESC:
      return SortDirection.Desc;
    default:
      return SortDirection.Natural;
  }
};

export const toTableSD = sd => {
  switch (sd) {
    case SortDirection.Asc:
      return TableSortDirection.ASC;
    case SortDirection.Desc:
      return TableSortDirection.DESC;
    case SortDirection.Natural:
      return null;
  }
};
