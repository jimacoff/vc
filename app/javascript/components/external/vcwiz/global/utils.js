import React from 'react';
import 'whatwg-fetch';
import parseDomain from 'parse-domain';
import Dimensions from 'react-dimensions';
import Storage from './storage.js.erb';
import { FounderEventNames, FounderEventPath } from './constants.js.erb';

export const _ffetch = function(path, data, opts) {
  if (opts.form) {
    delete opts.form;
    let formData = new FormData();
    Object.entries(data || {}).forEach(([k, v]) => {
      formData.append(k, v);
    });
    opts.body = formData;
  } else if (data) {
    opts.body = JSON.stringify(data);
    opts.headers['Content-Type'] = 'application/json';
  } else if (opts.method === 'GET' && opts.cache) {
    delete opts.cache;
    const cached = Storage.getExpr(path);
    if (cached) {
      return new Promise(cb => cb(cached));
    } else {
      return fetch(path, opts).then(resp => resp.json()).then(res => {
        Storage.setExpr(path, res, 3600);
        return res;
      });
    }
  }

  return fetch(path, opts).then(resp => resp.json());
};

export const ffetch = function(path, method = 'GET', data = null, opts = {}) {
  const allOpts = {
    ...opts,
    credentials: 'same-origin',
    headers: {
      'X-CSRF-Token': csrfToken(),
    },
    method,
  };
  return _ffetch(path, data, allOpts);
};

export const ffetchCached = function(path) {
  return ffetch(path, 'GET', null, {cache: true});
};

export const flush = function() {
  setTimeout(() => Storage.clearExpr(), 0);
};

export const csrfToken = function() {
  return window.gon.csrfToken;
};

export const isLoggedIn = function() {
  return !!window.gon.founder;
};

export const fullName = function(founder) {
  return `${founder.first_name} ${founder.last_name}`;
};

export const initials = function(founder) {
  return `${_.first(founder.first_name) || ''}${_.first(founder.last_name) || ''}`;
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

export const getDomain = (url) => {
  if (!url) {
    return null;
  }
  let parts = parseDomain(url);
  if (!parts) {
    return null;
  } else {
    return _.compact([parts.subdomain, parts.domain, parts.tld]).join('.');
  }
};

export const timestamp = () => Date.now();
export const flattenFilters = filters => _.pickBy(_.mapValues(filters, f => _.uniq(_.map(f, 'value')).join(',')), Boolean);
export const withSeparators = (sepFn, a) => _.flatMap(_.zip(a, _.times(a.length - 1, sepFn)));
export const withDots = a => withSeparators(i => <span key={`dot-${i}`} className="dot">·</span>, a);

export const withDims = klass => Dimensions({elementResize: true})(klass);

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
  if (!FounderEventNames.includes(name)) {
    throw new Error(`invalid event ${name}`);
  }
  return ffetch(FounderEventPath, 'POST', {event: {name, args}});
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