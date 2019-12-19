/**
 * Simplistic api interface containing a name field and init method
 */
class IApi {
  /**
   * Api Name
   *
   * @type {string}
   */
  name;

  /**
   * Called in CosmoScout.init
   */
  init() {
  }
}

/**
 * Api Container holding all registered apis.
 */
class CosmoScout {
  /**
   * @type {Map<string, Object>}
   * @private
   */
  static _apis = new Map();

  /**
   * Cache loaded templates
   *
   * @type {Map<string, DocumentFragment>}
   * @private
   */
  static _templates = new Map();

  /**
   * Init a list of apis
   *
   * @param apis {IApi[]}
   */
  static init(apis) {
    apis.forEach((Api) => {
      try {
        const instance = new Api();
        this.register(instance.name, instance);
        instance.init();
      } catch (e) {
        console.error(`Could not initialize ${Api}`);
      }
    });
  }

  /**
   * Initialize third party drop downs,
   * add input event listener,
   * initialize tooltips
   */
  static initInputs() {
    this.initDropDowns();
    this.initChecklabelInputs();
    this.initRadiolabelInputs();
    this.initTooltips();
    this.initDataCalls();
  }

  /**
   * @see {initInputs}
   * TODO Remove jQuery
   */
  static initDropDowns() {
    const dropdowns = $('.simple-value-dropdown');
    dropdowns.selectpicker();

    dropdowns.on('change', function () {
      if (this.id !== '') {
        CosmoScout.callNative(this.id, this.value);
      }
    });

    return;

    document.querySelectorAll('.simple-value-dropdown').forEach((dropdown) => {
      if (typeof dropdown.selectpicker !== 'undefined') {
        dropdown.selectpicker();
      }

      if (typeof dropdown.dataset.initialized !== 'undefined') {
        return;
      }

      dropdown.addEventListener('change', (event) => {
        if (event.target !== null && event.target.id !== '') {
          CosmoScout.callNative(event.target.id, event.target.value);
        }
      });

      dropdown.dataset.initialized = 'true';
    });
  }

  /**
   * @see {initInputs}
   */
  static initChecklabelInputs() {
    document.querySelectorAll('.checklabel input').forEach((input) => {
      if (typeof input.dataset.initialized !== 'undefined') {
        return;
      }

      input.addEventListener('change', (event) => {
        if (event.target !== null) {
          CosmoScout.callNative(event.target.id, event.target.checked);
        }
      });

      input.dataset.initialized = 'true';
    });
  }

  /**
   * @see {initInputs}
   */
  static initRadiolabelInputs() {
    document.querySelectorAll('.radiolabel input').forEach((input) => {
      if (typeof input.dataset.initialized !== 'undefined') {
        return;
      }

      input.addEventListener('change', (event) => {
        if (event.target !== null) {
          CosmoScout.callNative(event.target.id);
        }
      });

      input.dataset.initialized = 'true';
    });
  }

  /**
   * @see {initInputs}
   * @see {callNative}
   * Adds an onclick listener to every element containing [data-call="methodname"]
   * The method name gets passed to CosmoScout.callNative.
   * Arguments can be passed by separating the content with ','
   * E.g.: fly_to,Africa -> CosmoScout.callNative('fly_to', 'Africa')
   *       method,arg1,...,argN -> CosmoScout.callNative('method', arg1, ..., argN)
   */
  static initDataCalls() {
    document.querySelectorAll('[data-call]').forEach((input) => {
      if (typeof input.dataset.initialized !== 'undefined') {
        return;
      }

      input.addEventListener('click', () => {
        if (typeof input.dataset.call !== 'undefined') {
          const args = input.dataset.call.split(',');
          /* Somewhat ugly check if second arg is a number. Requires last char to be 'f' */
          if (typeof args[1] !== 'undefined' && args[1].slice(-1) === 'f') {
            args[1] = parseFloat(args[1]);
          }

          CosmoScout.callNative(...args);
        }
      });

      input.dataset.initialized = 'true';
    });
  }

  /**
   * @see {initInputs}
   */
  static initTooltips() {
    const config = { delay: 500, placement: 'auto', html: false };

    /* Boostrap Tooltips require jQuery for now */
    $('[data-toggle="tooltip"]').tooltip(config);
    config.placement = 'bottom';
    $('[data-toggle="tooltip-bottom"]').tooltip(config);

    return;

    /* Init tooltips without jQuery */
    document.querySelectorAll('[data-toggle="tooltip"]').forEach((tooltip) => {
      if (typeof tooltip.tooltip !== 'undefined') {
        tooltip.tooltip(config);
      }
    });

    document.querySelectorAll('[data-toggle="tooltip-bottom"]').forEach((tooltip) => {
      if (typeof tooltip.tooltip !== 'undefined') {
        config.placement = 'bottom';
        tooltip.tooltip(config);
      }
    });
  }

  /**
   * Appends a script element to the body
   *
   * @param url {string} Absolute or local file path
   * @param init {Function} Method gets run on script load
   */
  static registerJavaScript(url, init) {
    const script = document.createElement('script');
    script.setAttribute('type', 'text/javascript');
    script.setAttribute('src', url);

    if (typeof init !== 'undefined') {
      script.addEventListener('load', init);
      script.addEventListener('readystatechange', init);
    }

    document.body.appendChild(script);
  }

  /**
   * Removes a script element by url
   *
   * @param url {string}
   */
  static unregisterJavaScript(url) {
    document.querySelectorAll('script').forEach((element) => {
      if (typeof element.src !== 'undefined'
        && (element.src === url || element.src === this._localizeUrl(url))) {
        document.body.removeChild(element);
      }
    });
  }

  /**
   * Appends a link stylesheet to the head
   *
   * @param url {string}
   */
  static registerCss(url) {
    const link = document.createElement('link');
    link.setAttribute('type', 'text/css');
    link.setAttribute('rel', 'stylesheet');
    link.setAttribute('href', url);

    document.head.appendChild(link);
  }

  /**
   * Removes a stylesheet by url
   *
   * @param url {string}
   */
  static unregisterCss(url) {
    document.querySelectorAll('link').forEach((element) => {
      if (typeof element.href !== 'undefined'
        && (element.href === url || element.href === this._localizeUrl(url))) {
        document.head.removeChild(element);
      }
    });
  }

  /**
   * Tries to load the template content of 'id-template'
   * Returns false if no template was found, HTMLElement otherwise.
   *
   * @param id {string} Template element id without '-template' suffix
   * @return {boolean|HTMLElement}
   */
  static loadTemplateContent(id) {
    id = `${id}-template`;

    if (this._templates.has(id)) {
      return this._templates.get(id).cloneNode(true).firstElementChild;
    }

    const template = document.getElementById(id);

    if (template === null) {
      console.error(`Template '#${id}' not found.`);
      return false;
    }

    const { content } = template;
    this._templates.set(id, content);

    return content.cloneNode(true).firstElementChild;
  }

  /**
   * Clear the innerHtml of an element if it exists
   *
   * @param element {string|HTMLElement} Element or ID
   * @return {void}
   */
  static clearHtml(element) {
    if (typeof element === 'string') {
      element = document.getElementById(element);
    }

    if (element !== null && element instanceof HTMLElement) {
      while (element.firstChild !== null) {
        element.removeChild(element.firstChild);
      }
    } else {
      console.warn('Element could not be cleared.');
    }
  }

  /**
   * Initialize a noUiSlider
   *
   * @param id {string}
   * @param min {number}
   * @param max {number}
   * @param step {number}
   * @param start {number[]}
   */
  static initSlider(id, min, max, step, start) {
    const slider = document.getElementById(id);

    if (typeof noUiSlider === 'undefined') {
      console.error('\'noUiSlider\' is not defined.');
      return;
    }

    noUiSlider.create(slider, {
      start,
      connect: (start.length === 1 ? 'lower' : true),
      step,
      range: { min, max },
      format: {
        to(value) {
          return Format.beautifyNumber(value);
        },
        from(value) {
          return Number(parseFloat(value));
        },
      },
    });

    slider.noUiSlider.on('slide', (values, handle, unencoded) => {
      if (Array.isArray(unencoded)) {
        CosmoScout.callNative(id, unencoded[handle], handle);
      } else {
        CosmoScout.callNative(id, unencoded, 0);
      }
    });
  }

  /**
   * Set a noUiSlider value
   *
   * @param id {string} Slider ID
   * @param value {number} Value
   */
  static setSliderValue(id, ...value) {
    const slider = document.getElementById(id);

    if (slider !== null && typeof slider.noUiSlider !== 'undefined') {
      if (value.length === 1) {
        slider.noUiSlider.set(value[0]);
      } else {
        slider.noUiSlider.set(value);
      }
    } else {
      console.warn(`Slider '${id} 'not found or 'noUiSlider' not active.`);
    }
  }

  /**
   * Global entry point to call any method on any registered api
   *
   * @param api {string} Name of api
   * @param method {string} Method name
   * @param args {string|number|boolean|Function|Object} Arguments to pass through
   * @return {*}
   */
  static call(api, method, ...args) {
    if (method !== 'setUserPosition' && method !== 'setNorthDirection' && method !== 'setSpeed' && method !== 'setDate') {
      // console.log(`Calling '${method}' on '${api}'`);
    }

    if (this._apis.has(api)) {
      if (typeof (this._apis.get(api))[method] !== 'undefined' && method[0] !== '_') {
        return (this._apis.get(api))[method](...args);
      }
      console.error(`'${method}' does not exist on api '${api}'.`);
    } else {
      console.error(`Api '${api}' is not registered.`);
    }
  }

  /**
   * window.call_native wrapper
   *
   * @param fn {string}
   * @param args {any}
   * @return {*}
   */
  static callNative(fn, ...args) {
    return window.call_native(fn, ...args);
  }

  /**
   * Register an api object
   *
   * @param name {string}
   * @param api {Object}
   */
  static register(name, api) {
    this[name] = api;
    this._apis.set(name, api);
  }

  /**
   * Remove a registered api by name
   *
   * @param name {string}
   */
  static remove(name) {
    delete this[name];
    this._apis.delete(name);
  }

  /**
   * Get a registered api object
   *
   * @param name {string}
   * @return {Object}
   */
  static getApi(name) {
    return this._apis.get(name);
  }

  /**
   * Localizes a filename
   *
   * @param url {string}
   * @return {string}
   * @private
   */
  static _localizeUrl(url) {
    return `file://../share/resources/gui/${url}`;
  }
}
