let wasm;
export function __wbg_set_wasm(val) {
    wasm = val;
}


let cachedUint8ArrayMemory0 = null;

function getUint8ArrayMemory0() {
    if (cachedUint8ArrayMemory0 === null || cachedUint8ArrayMemory0.byteLength === 0) {
        cachedUint8ArrayMemory0 = new Uint8Array(wasm.memory.buffer);
    }
    return cachedUint8ArrayMemory0;
}

let cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });

cachedTextDecoder.decode();

const MAX_SAFARI_DECODE_BYTES = 2146435072;
let numBytesDecoded = 0;
function decodeText(ptr, len) {
    numBytesDecoded += len;
    if (numBytesDecoded >= MAX_SAFARI_DECODE_BYTES) {
        cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
        cachedTextDecoder.decode();
        numBytesDecoded = len;
    }
    return cachedTextDecoder.decode(getUint8ArrayMemory0().subarray(ptr, ptr + len));
}

function getStringFromWasm0(ptr, len) {
    ptr = ptr >>> 0;
    return decodeText(ptr, len);
}

let WASM_VECTOR_LEN = 0;

const cachedTextEncoder = new TextEncoder();

if (!('encodeInto' in cachedTextEncoder)) {
    cachedTextEncoder.encodeInto = function (arg, view) {
        const buf = cachedTextEncoder.encode(arg);
        view.set(buf);
        return {
            read: arg.length,
            written: buf.length
        };
    }
}

function passStringToWasm0(arg, malloc, realloc) {

    if (realloc === undefined) {
        const buf = cachedTextEncoder.encode(arg);
        const ptr = malloc(buf.length, 1) >>> 0;
        getUint8ArrayMemory0().subarray(ptr, ptr + buf.length).set(buf);
        WASM_VECTOR_LEN = buf.length;
        return ptr;
    }

    let len = arg.length;
    let ptr = malloc(len, 1) >>> 0;

    const mem = getUint8ArrayMemory0();

    let offset = 0;

    for (; offset < len; offset++) {
        const code = arg.charCodeAt(offset);
        if (code > 0x7F) break;
        mem[ptr + offset] = code;
    }

    if (offset !== len) {
        if (offset !== 0) {
            arg = arg.slice(offset);
        }
        ptr = realloc(ptr, len, len = offset + arg.length * 3, 1) >>> 0;
        const view = getUint8ArrayMemory0().subarray(ptr + offset, ptr + len);
        const ret = cachedTextEncoder.encodeInto(arg, view);

        offset += ret.written;
        ptr = realloc(ptr, len, offset, 1) >>> 0;
    }

    WASM_VECTOR_LEN = offset;
    return ptr;
}

let cachedDataViewMemory0 = null;

function getDataViewMemory0() {
    if (cachedDataViewMemory0 === null || cachedDataViewMemory0.buffer.detached === true || (cachedDataViewMemory0.buffer.detached === undefined && cachedDataViewMemory0.buffer !== wasm.memory.buffer)) {
        cachedDataViewMemory0 = new DataView(wasm.memory.buffer);
    }
    return cachedDataViewMemory0;
}

function addToExternrefTable0(obj) {
    const idx = wasm.__externref_table_alloc();
    wasm.__wbindgen_export_4.set(idx, obj);
    return idx;
}

function handleError(f, args) {
    try {
        return f.apply(this, args);
    } catch (e) {
        const idx = addToExternrefTable0(e);
        wasm.__wbindgen_exn_store(idx);
    }
}

function isLikeNone(x) {
    return x === undefined || x === null;
}

function getArrayU8FromWasm0(ptr, len) {
    ptr = ptr >>> 0;
    return getUint8ArrayMemory0().subarray(ptr / 1, ptr / 1 + len);
}

function debugString(val) {
    // primitive types
    const type = typeof val;
    if (type == 'number' || type == 'boolean' || val == null) {
        return  `${val}`;
    }
    if (type == 'string') {
        return `"${val}"`;
    }
    if (type == 'symbol') {
        const description = val.description;
        if (description == null) {
            return 'Symbol';
        } else {
            return `Symbol(${description})`;
        }
    }
    if (type == 'function') {
        const name = val.name;
        if (typeof name == 'string' && name.length > 0) {
            return `Function(${name})`;
        } else {
            return 'Function';
        }
    }
    // objects
    if (Array.isArray(val)) {
        const length = val.length;
        let debug = '[';
        if (length > 0) {
            debug += debugString(val[0]);
        }
        for(let i = 1; i < length; i++) {
            debug += ', ' + debugString(val[i]);
        }
        debug += ']';
        return debug;
    }
    // Test for built-in
    const builtInMatches = /\[object ([^\]]+)\]/.exec(toString.call(val));
    let className;
    if (builtInMatches && builtInMatches.length > 1) {
        className = builtInMatches[1];
    } else {
        // Failed to match the standard '[object ClassName]'
        return toString.call(val);
    }
    if (className == 'Object') {
        // we're a user defined class or Object
        // JSON.stringify avoids problems with cycles, and is generally much
        // easier than looping through ownProperties of `val`.
        try {
            return 'Object(' + JSON.stringify(val) + ')';
        } catch (_) {
            return 'Object';
        }
    }
    // errors
    if (val instanceof Error) {
        return `${val.name}: ${val.message}\n${val.stack}`;
    }
    // TODO we could test for more things here, like `Set`s and `Map`s.
    return className;
}

function getArrayJsValueFromWasm0(ptr, len) {
    ptr = ptr >>> 0;
    const mem = getDataViewMemory0();
    const result = [];
    for (let i = ptr; i < ptr + 4 * len; i += 4) {
        result.push(wasm.__wbindgen_export_4.get(mem.getUint32(i, true)));
    }
    wasm.__externref_drop_slice(ptr, len);
    return result;
}

const CLOSURE_DTORS = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(
state => {
    wasm.__wbindgen_export_7.get(state.dtor)(state.a, state.b);
}
);

function makeMutClosure(arg0, arg1, dtor, f) {
    const state = { a: arg0, b: arg1, cnt: 1, dtor };
    const real = (...args) => {

        // First up with a closure we increment the internal reference
        // count. This ensures that the Rust closure environment won't
        // be deallocated while we're invoking it.
        state.cnt++;
        const a = state.a;
        state.a = 0;
        try {
            return f(a, state.b, ...args);
        } finally {
            if (--state.cnt === 0) {
                wasm.__wbindgen_export_7.get(state.dtor)(a, state.b);
                CLOSURE_DTORS.unregister(state);
            } else {
                state.a = a;
            }
        }
    };
    real.original = state;
    CLOSURE_DTORS.register(real, state, state);
    return real;
}

function takeFromExternrefTable0(idx) {
    const value = wasm.__wbindgen_export_4.get(idx);
    wasm.__externref_table_dealloc(idx);
    return value;
}

function _assertClass(instance, klass) {
    if (!(instance instanceof klass)) {
        throw new Error(`expected instance of ${klass.name}`);
    }
}

function passArrayJsValueToWasm0(array, malloc) {
    const ptr = malloc(array.length * 4, 4) >>> 0;
    for (let i = 0; i < array.length; i++) {
        const add = addToExternrefTable0(array[i]);
        getDataViewMemory0().setUint32(ptr + 4 * i, add, true);
    }
    WASM_VECTOR_LEN = array.length;
    return ptr;
}
/**
 * Computes a contract address from deployment parameters
 *
 * # Parameters
 * * `class_hash` - Contract class hash as hex string
 * * `salt` - Salt value as hex string
 * * `constructor_calldata` - Array of constructor parameters as hex strings
 * * `deployer_address` - Address of deployer as hex string
 *
 * # Returns
 * Result containing computed contract address as hex string or error
 * @param {string} class_hash
 * @param {string} salt
 * @param {string[]} constructor_calldata
 * @param {string} deployer_address
 * @returns {string}
 */
export function getContractAddress(class_hash, salt, constructor_calldata, deployer_address) {
    let deferred6_0;
    let deferred6_1;
    try {
        const ptr0 = passStringToWasm0(class_hash, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passStringToWasm0(salt, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len1 = WASM_VECTOR_LEN;
        const ptr2 = passArrayJsValueToWasm0(constructor_calldata, wasm.__wbindgen_malloc);
        const len2 = WASM_VECTOR_LEN;
        const ptr3 = passStringToWasm0(deployer_address, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len3 = WASM_VECTOR_LEN;
        const ret = wasm.getContractAddress(ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3);
        var ptr5 = ret[0];
        var len5 = ret[1];
        if (ret[3]) {
            ptr5 = 0; len5 = 0;
            throw takeFromExternrefTable0(ret[2]);
        }
        deferred6_0 = ptr5;
        deferred6_1 = len5;
        return getStringFromWasm0(ptr5, len5);
    } finally {
        wasm.__wbindgen_free(deferred6_0, deferred6_1, 1);
    }
}

/**
 * Computes a selector from a tag string
 *
 * # Parameters
 * * `tag` - Tag string to compute selector from
 *
 * # Returns
 * Selector as hex string
 * @param {string} tag
 * @returns {string}
 */
export function getSelectorFromTag(tag) {
    let deferred2_0;
    let deferred2_1;
    try {
        const ptr0 = passStringToWasm0(tag, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.getSelectorFromTag(ptr0, len0);
        deferred2_0 = ret[0];
        deferred2_1 = ret[1];
        return getStringFromWasm0(ret[0], ret[1]);
    } finally {
        wasm.__wbindgen_free(deferred2_0, deferred2_1, 1);
    }
}

/**
 * Computes a Poseidon hash of the inputs
 *
 * # Parameters
 * * `inputs` - Array of field elements as hex strings
 *
 * # Returns
 * Result containing hash as hex string or error
 * @param {string[]} inputs
 * @returns {string}
 */
export function poseidonHash(inputs) {
    let deferred3_0;
    let deferred3_1;
    try {
        const ptr0 = passArrayJsValueToWasm0(inputs, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.poseidonHash(ptr0, len0);
        var ptr2 = ret[0];
        var len2 = ret[1];
        if (ret[3]) {
            ptr2 = 0; len2 = 0;
            throw takeFromExternrefTable0(ret[2]);
        }
        deferred3_0 = ptr2;
        deferred3_1 = len2;
        return getStringFromWasm0(ptr2, len2);
    } finally {
        wasm.__wbindgen_free(deferred3_0, deferred3_1, 1);
    }
}

/**
 * Gets a selector from a function name
 *
 * # Parameters
 * * `name` - Function name to compute selector from
 *
 * # Returns
 * Result containing selector as hex string or error
 * @param {string} name
 * @returns {string}
 */
export function getSelectorFromName(name) {
    let deferred3_0;
    let deferred3_1;
    try {
        const ptr0 = passStringToWasm0(name, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.getSelectorFromName(ptr0, len0);
        var ptr2 = ret[0];
        var len2 = ret[1];
        if (ret[3]) {
            ptr2 = 0; len2 = 0;
            throw takeFromExternrefTable0(ret[2]);
        }
        deferred3_0 = ptr2;
        deferred3_1 = len2;
        return getStringFromWasm0(ptr2, len2);
    } finally {
        wasm.__wbindgen_free(deferred3_0, deferred3_1, 1);
    }
}

/**
 * Computes the Starknet variant of Keccak hash
 *
 * # Parameters
 * * `inputs` - Byte array to hash
 *
 * # Returns
 * Result containing hash as hex string or error
 * @param {Uint8Array} inputs
 * @returns {string}
 */
export function starknetKeccak(inputs) {
    let deferred2_0;
    let deferred2_1;
    try {
        const ret = wasm.starknetKeccak(inputs);
        var ptr1 = ret[0];
        var len1 = ret[1];
        if (ret[3]) {
            ptr1 = 0; len1 = 0;
            throw takeFromExternrefTable0(ret[2]);
        }
        deferred2_0 = ptr1;
        deferred2_1 = len1;
        return getStringFromWasm0(ptr1, len1);
    } finally {
        wasm.__wbindgen_free(deferred2_0, deferred2_1, 1);
    }
}

/**
 * Converts a short string to a Cairo field element
 *
 * # Parameters
 * * `str` - String to convert
 *
 * # Returns
 * Result containing field element as hex string or error
 * @param {string} str
 * @returns {string}
 */
export function cairoShortStringToFelt(str) {
    let deferred3_0;
    let deferred3_1;
    try {
        const ptr0 = passStringToWasm0(str, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.cairoShortStringToFelt(ptr0, len0);
        var ptr2 = ret[0];
        var len2 = ret[1];
        if (ret[3]) {
            ptr2 = 0; len2 = 0;
            throw takeFromExternrefTable0(ret[2]);
        }
        deferred3_0 = ptr2;
        deferred3_1 = len2;
        return getStringFromWasm0(ptr2, len2);
    } finally {
        wasm.__wbindgen_free(deferred3_0, deferred3_1, 1);
    }
}

/**
 * Parses a Cairo field element into a short string
 *
 * # Parameters
 * * `str` - Field element as hex string
 *
 * # Returns
 * Result containing parsed string or error
 * @param {string} str
 * @returns {string}
 */
export function parseCairoShortString(str) {
    let deferred3_0;
    let deferred3_1;
    try {
        const ptr0 = passStringToWasm0(str, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.parseCairoShortString(ptr0, len0);
        var ptr2 = ret[0];
        var len2 = ret[1];
        if (ret[3]) {
            ptr2 = 0; len2 = 0;
            throw takeFromExternrefTable0(ret[2]);
        }
        deferred3_0 = ptr2;
        deferred3_1 = len2;
        return getStringFromWasm0(ptr2, len2);
    } finally {
        wasm.__wbindgen_free(deferred3_0, deferred3_1, 1);
    }
}

function __wbg_adapter_8(arg0, arg1) {
    wasm.wasm_bindgen__convert__closures_____invoke__hdbf7430e6569e36e(arg0, arg1);
}

function __wbg_adapter_15(arg0, arg1, arg2) {
    wasm.closure1120_externref_shim(arg0, arg1, arg2);
}

function __wbg_adapter_24(arg0, arg1) {
    wasm.wasm_bindgen__convert__closures_____invoke__h40fd58b8c8fdefef(arg0, arg1);
}

function __wbg_adapter_283(arg0, arg1, arg2, arg3) {
    wasm.closure1302_externref_shim(arg0, arg1, arg2, arg3);
}

const __wbindgen_enum_ReadableStreamType = ["bytes"];

const __wbindgen_enum_ReferrerPolicy = ["", "no-referrer", "no-referrer-when-downgrade", "origin", "origin-when-cross-origin", "unsafe-url", "same-origin", "strict-origin", "strict-origin-when-cross-origin"];

const __wbindgen_enum_RequestCache = ["default", "no-store", "reload", "no-cache", "force-cache", "only-if-cached"];

const __wbindgen_enum_RequestCredentials = ["omit", "same-origin", "include"];

const __wbindgen_enum_RequestMode = ["same-origin", "no-cors", "cors", "navigate"];

const __wbindgen_enum_RequestRedirect = ["follow", "error", "manual"];

const AccountFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_account_free(ptr >>> 0, 1));

export class Account {

    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(Account.prototype);
        obj.__wbg_ptr = ptr;
        AccountFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        AccountFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_account_free(ptr, 0);
    }
    /**
     * Creates a new account instance with the given private key and address
     *
     * # Parameters
     * * `provider` - Provider instance
     * * `private_key` - Private key as hex string
     * * `address` - Account address as hex string
     *
     * # Returns
     * Result containing Account instance or error
     * @param {Provider} provider
     * @param {string} private_key
     * @param {string} address
     */
    constructor(provider, private_key, address) {
        _assertClass(provider, Provider);
        const ptr0 = passStringToWasm0(private_key, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passStringToWasm0(address, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len1 = WASM_VECTOR_LEN;
        const ret = wasm.account_new(provider.__wbg_ptr, ptr0, len0, ptr1, len1);
        return ret;
    }
    /**
     * Returns the account's address
     *
     * # Returns
     * Result containing address as hex string or error
     * @returns {string}
     */
    address() {
        let deferred2_0;
        let deferred2_1;
        try {
            const ret = wasm.account_address(this.__wbg_ptr);
            var ptr1 = ret[0];
            var len1 = ret[1];
            if (ret[3]) {
                ptr1 = 0; len1 = 0;
                throw takeFromExternrefTable0(ret[2]);
            }
            deferred2_0 = ptr1;
            deferred2_1 = len1;
            return getStringFromWasm0(ptr1, len1);
        } finally {
            wasm.__wbindgen_free(deferred2_0, deferred2_1, 1);
        }
    }
    /**
     * Returns the account's chain ID
     *
     * # Returns
     * Result containing chain ID as hex string or error
     * @returns {string}
     */
    chainId() {
        let deferred2_0;
        let deferred2_1;
        try {
            const ret = wasm.account_chainId(this.__wbg_ptr);
            var ptr1 = ret[0];
            var len1 = ret[1];
            if (ret[3]) {
                ptr1 = 0; len1 = 0;
                throw takeFromExternrefTable0(ret[2]);
            }
            deferred2_0 = ptr1;
            deferred2_1 = len1;
            return getStringFromWasm0(ptr1, len1);
        } finally {
            wasm.__wbindgen_free(deferred2_0, deferred2_1, 1);
        }
    }
    /**
     * Sets the block ID for subsequent operations
     *
     * # Parameters
     * * `block_id` - Block ID as hex string
     *
     * # Returns
     * Result containing unit or error
     * @param {string} block_id
     */
    setBlockId(block_id) {
        const ptr0 = passStringToWasm0(block_id, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.account_setBlockId(this.__wbg_ptr, ptr0, len0);
        if (ret[1]) {
            throw takeFromExternrefTable0(ret[0]);
        }
    }
    /**
     * Executes a raw transaction
     *
     * # Parameters
     * * `calldata` - Array of contract calls to execute
     *
     * # Returns
     * Result containing transaction hash as hex string or error
     * @param {Call[]} calldata
     * @returns {Promise<string>}
     */
    executeRaw(calldata) {
        const ptr0 = passArrayJsValueToWasm0(calldata, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.account_executeRaw(this.__wbg_ptr, ptr0, len0);
        return ret;
    }
    /**
     * Deploys a burner wallet
     *
     * # Parameters
     * * `private_key` - Private key for the burner wallet as hex string
     *
     * # Returns
     * Result containing new Account instance or error
     * @param {string} private_key
     * @returns {Promise<Account>}
     */
    deployBurner(private_key) {
        const ptr0 = passStringToWasm0(private_key, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.account_deployBurner(this.__wbg_ptr, ptr0, len0);
        return ret;
    }
    /**
     * Gets the current nonce for the account
     *
     * # Returns
     * Result containing nonce as hex string or error
     * @returns {Promise<string>}
     */
    nonce() {
        const ret = wasm.account_nonce(this.__wbg_ptr);
        return ret;
    }
    /**
     * Gets the provider of the account
     *
     * # Returns
     * Result containing provider as hex string or error
     * @returns {Provider}
     */
    provider() {
        const ret = wasm.account_provider(this.__wbg_ptr);
        return Provider.__wrap(ret);
    }
}
if (Symbol.dispose) Account.prototype[Symbol.dispose] = Account.prototype.free;

const ByteArrayFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_bytearray_free(ptr >>> 0, 1));

export class ByteArray {

    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(ByteArray.prototype);
        obj.__wbg_ptr = ptr;
        ByteArrayFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        ByteArrayFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_bytearray_free(ptr, 0);
    }
    /**
     * Serializes a string into a Cairo byte array
     *
     * # Parameters
     * * `str` - String to serialize
     *
     * # Returns
     * Result containing array of field elements as hex strings or error
     * @param {string} str
     */
    constructor(str) {
        const ptr0 = passStringToWasm0(str, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.bytearray_new(ptr0, len0);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        this.__wbg_ptr = ret[0] >>> 0;
        ByteArrayFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * Serializes a Cairo byte array into a vector of field elements as hex strings
     *
     * # Returns
     * Result containing vector of field elements as hex strings or error
     * @returns {string[]}
     */
    toRaw() {
        const ret = wasm.bytearray_toRaw(this.__wbg_ptr);
        if (ret[3]) {
            throw takeFromExternrefTable0(ret[2]);
        }
        var v1 = getArrayJsValueFromWasm0(ret[0], ret[1]).slice();
        wasm.__wbindgen_free(ret[0], ret[1] * 4, 4);
        return v1;
    }
    /**
     * Deserializes a Cairo byte array into a string
     *
     * # Parameters
     * * `felts` - Array of field elements as hex strings
     *
     * # Returns
     * Result containing deserialized string or error
     * @param {string[]} felts
     * @returns {ByteArray}
     */
    static fromRaw(felts) {
        const ptr0 = passArrayJsValueToWasm0(felts, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.bytearray_fromRaw(ptr0, len0);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        return ByteArray.__wrap(ret[0]);
    }
    /**
     * Converts a Cairo byte array to a string
     *
     * # Returns
     * Result containing string representation of the byte array or error
     * @returns {string}
     */
    toString() {
        let deferred2_0;
        let deferred2_1;
        try {
            const ret = wasm.bytearray_toString(this.__wbg_ptr);
            var ptr1 = ret[0];
            var len1 = ret[1];
            if (ret[3]) {
                ptr1 = 0; len1 = 0;
                throw takeFromExternrefTable0(ret[2]);
            }
            deferred2_0 = ptr1;
            deferred2_1 = len1;
            return getStringFromWasm0(ptr1, len1);
        } finally {
            wasm.__wbindgen_free(deferred2_0, deferred2_1, 1);
        }
    }
}
if (Symbol.dispose) ByteArray.prototype[Symbol.dispose] = ByteArray.prototype.free;

const IntoUnderlyingByteSourceFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_intounderlyingbytesource_free(ptr >>> 0, 1));

export class IntoUnderlyingByteSource {

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        IntoUnderlyingByteSourceFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_intounderlyingbytesource_free(ptr, 0);
    }
    /**
     * @returns {ReadableStreamType}
     */
    get type() {
        const ret = wasm.intounderlyingbytesource_type(this.__wbg_ptr);
        return __wbindgen_enum_ReadableStreamType[ret];
    }
    /**
     * @returns {number}
     */
    get autoAllocateChunkSize() {
        const ret = wasm.intounderlyingbytesource_autoAllocateChunkSize(this.__wbg_ptr);
        return ret >>> 0;
    }
    /**
     * @param {ReadableByteStreamController} controller
     */
    start(controller) {
        wasm.intounderlyingbytesource_start(this.__wbg_ptr, controller);
    }
    /**
     * @param {ReadableByteStreamController} controller
     * @returns {Promise<any>}
     */
    pull(controller) {
        const ret = wasm.intounderlyingbytesource_pull(this.__wbg_ptr, controller);
        return ret;
    }
    cancel() {
        const ptr = this.__destroy_into_raw();
        wasm.intounderlyingbytesource_cancel(ptr);
    }
}
if (Symbol.dispose) IntoUnderlyingByteSource.prototype[Symbol.dispose] = IntoUnderlyingByteSource.prototype.free;

const IntoUnderlyingSinkFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_intounderlyingsink_free(ptr >>> 0, 1));

export class IntoUnderlyingSink {

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        IntoUnderlyingSinkFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_intounderlyingsink_free(ptr, 0);
    }
    /**
     * @param {any} chunk
     * @returns {Promise<any>}
     */
    write(chunk) {
        const ret = wasm.intounderlyingsink_write(this.__wbg_ptr, chunk);
        return ret;
    }
    /**
     * @returns {Promise<any>}
     */
    close() {
        const ptr = this.__destroy_into_raw();
        const ret = wasm.intounderlyingsink_close(ptr);
        return ret;
    }
    /**
     * @param {any} reason
     * @returns {Promise<any>}
     */
    abort(reason) {
        const ptr = this.__destroy_into_raw();
        const ret = wasm.intounderlyingsink_abort(ptr, reason);
        return ret;
    }
}
if (Symbol.dispose) IntoUnderlyingSink.prototype[Symbol.dispose] = IntoUnderlyingSink.prototype.free;

const IntoUnderlyingSourceFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_intounderlyingsource_free(ptr >>> 0, 1));

export class IntoUnderlyingSource {

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        IntoUnderlyingSourceFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_intounderlyingsource_free(ptr, 0);
    }
    /**
     * @param {ReadableStreamDefaultController} controller
     * @returns {Promise<any>}
     */
    pull(controller) {
        const ret = wasm.intounderlyingsource_pull(this.__wbg_ptr, controller);
        return ret;
    }
    cancel() {
        const ptr = this.__destroy_into_raw();
        wasm.intounderlyingsource_cancel(ptr);
    }
}
if (Symbol.dispose) IntoUnderlyingSource.prototype[Symbol.dispose] = IntoUnderlyingSource.prototype.free;

const ProviderFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_provider_free(ptr >>> 0, 1));

export class Provider {

    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(Provider.prototype);
        obj.__wbg_ptr = ptr;
        ProviderFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        ProviderFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_provider_free(ptr, 0);
    }
    /**
     * Creates a new Starknet provider instance for a given RPC URL
     *
     * # Parameters
     * * `rpc_url` - URL of the RPC endpoint
     *
     * # Returns
     * Result containing Provider instance or error
     * @param {string} rpc_url
     */
    constructor(rpc_url) {
        const ptr0 = passStringToWasm0(rpc_url, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.provider_new(ptr0, len0);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        this.__wbg_ptr = ret[0] >>> 0;
        ProviderFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * Calls a Starknet contract view function
     *
     * # Parameters
     * * `call` - Call parameters including contract address and function
     * * `block_id` - Block identifier for the call
     *
     * # Returns
     * Result containing array of field elements or error
     * @param {Call} call
     * @param {BlockId} block_id
     * @returns {Promise<Array<any>>}
     */
    call(call, block_id) {
        const ret = wasm.provider_call(this.__wbg_ptr, call, block_id);
        return ret;
    }
    /**
     * Waits for a transaction to be confirmed
     *
     * # Parameters
     * * `txn_hash` - Transaction hash as hex string
     *
     * # Returns
     * Result containing success boolean or error
     * @param {string} txn_hash
     * @returns {Promise<boolean>}
     */
    waitForTransaction(txn_hash) {
        const ptr0 = passStringToWasm0(txn_hash, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.provider_waitForTransaction(this.__wbg_ptr, ptr0, len0);
        return ret;
    }
    /**
     * Gets the chain id of the provider
     *
     * # Returns
     * Result containing chain id as hex string or error
     * @returns {Promise<string>}
     */
    chainId() {
        const ret = wasm.provider_chainId(this.__wbg_ptr);
        return ret;
    }
}
if (Symbol.dispose) Provider.prototype[Symbol.dispose] = Provider.prototype.free;

const SigningKeyFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_signingkey_free(ptr >>> 0, 1));

export class SigningKey {

    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(SigningKey.prototype);
        obj.__wbg_ptr = ptr;
        SigningKeyFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        SigningKeyFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_signingkey_free(ptr, 0);
    }
    /**
     * Generates a new random signing key
     *
     * # Returns
     * Private key as hex string
     * @param {string} secret_scalar
     */
    constructor(secret_scalar) {
        const ptr0 = passStringToWasm0(secret_scalar, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.signingkey_new(ptr0, len0);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        this.__wbg_ptr = ret[0] >>> 0;
        SigningKeyFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * Initializes a new signing key from a secret scalar
     *
     * # Parameters
     * * `secret_scalar` - Secret scalar as hex string
     *
     * # Returns
     * Result containing signing key or error
     * @returns {SigningKey}
     */
    static fromRandom() {
        const ret = wasm.signingkey_fromRandom();
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        return SigningKey.__wrap(ret[0]);
    }
    /**
     * Returns the secret scalar of the signing key
     *
     * # Returns
     * Result containing secret scalar as hex string or error
     * @returns {string}
     */
    secretScalar() {
        let deferred2_0;
        let deferred2_1;
        try {
            const ret = wasm.signingkey_secretScalar(this.__wbg_ptr);
            var ptr1 = ret[0];
            var len1 = ret[1];
            if (ret[3]) {
                ptr1 = 0; len1 = 0;
                throw takeFromExternrefTable0(ret[2]);
            }
            deferred2_0 = ptr1;
            deferred2_1 = len1;
            return getStringFromWasm0(ptr1, len1);
        } finally {
            wasm.__wbindgen_free(deferred2_0, deferred2_1, 1);
        }
    }
    /**
     * Signs a message hash with a private key
     *
     * # Parameters
     * * `private_key` - Private key as hex string
     * * `hash` - Message hash as hex string
     *
     * # Returns
     * Result containing signature or error
     * @param {string} hash
     * @returns {Signature}
     */
    sign(hash) {
        const ptr0 = passStringToWasm0(hash, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.signingkey_sign(this.__wbg_ptr, ptr0, len0);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        return takeFromExternrefTable0(ret[0]);
    }
    /**
     * Returns the verifying key of the signing key
     *
     * # Returns
     * Result containing verifying key or error
     * @returns {VerifyingKey}
     */
    verifyingKey() {
        const ret = wasm.signingkey_verifyingKey(this.__wbg_ptr);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        return VerifyingKey.__wrap(ret[0]);
    }
}
if (Symbol.dispose) SigningKey.prototype[Symbol.dispose] = SigningKey.prototype.free;

const SubscriptionFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_subscription_free(ptr >>> 0, 1));

export class Subscription {

    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(Subscription.prototype);
        obj.__wbg_ptr = ptr;
        SubscriptionFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        SubscriptionFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_subscription_free(ptr, 0);
    }
    /**
     * @returns {bigint}
     */
    get id() {
        const ret = wasm.__wbg_get_subscription_id(this.__wbg_ptr);
        return BigInt.asUintN(64, ret);
    }
    /**
     * @param {bigint} arg0
     */
    set id(arg0) {
        wasm.__wbg_set_subscription_id(this.__wbg_ptr, arg0);
    }
    /**
     * Cancels an active subscription
     */
    cancel() {
        const ptr = this.__destroy_into_raw();
        wasm.subscription_cancel(ptr);
    }
}
if (Symbol.dispose) Subscription.prototype[Symbol.dispose] = Subscription.prototype.free;

const ToriiClientFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_toriiclient_free(ptr >>> 0, 1));

export class ToriiClient {

    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(ToriiClient.prototype);
        obj.__wbg_ptr = ptr;
        ToriiClientFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        ToriiClientFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_toriiclient_free(ptr, 0);
    }
    /**
     * Creates a new Torii client with the given configuration
     *
     * # Parameters
     * * `config` - Client configuration including URLs and world address
     *
     * # Returns
     * Result containing ToriiClient instance or error
     * @param {ClientConfig} config
     */
    constructor(config) {
        const ret = wasm.toriiclient_new(config);
        return ret;
    }
    /**
     * Gets controllers along with their usernames for the given contract addresses
     *
     * # Parameters
     * * `contract_addresses` - Array of contract addresses as hex strings. If empty, all
     *   controllers will be returned.
     *
     * # Returns
     * Result containing controllers or error
     * @param {ControllerQuery} query
     * @returns {Promise<Controllers>}
     */
    getControllers(query) {
        const ret = wasm.toriiclient_getControllers(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Gets contracts matching the given query
     *
     * # Parameters
     * * `query` - ContractQuery parameters
     *
     * # Returns
     * Result containing contracts or error
     * @param {ContractQuery} query
     * @returns {Promise<Contracts>}
     */
    getContracts(query) {
        const ret = wasm.toriiclient_getContracts(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Gets transactions matching the given query
     *
     * # Parameters
     * * `query` - Query parameters
     *
     * # Returns
     * Result containing transactions or error
     * @param {TransactionQuery} query
     * @returns {Promise<Transactions>}
     */
    getTransactions(query) {
        const ret = wasm.toriiclient_getTransactions(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Subscribes to transactions
     *
     * # Parameters
     * * `filter` - Filter parameters
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {TransactionFilter | null | undefined} filter
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onTransaction(filter, callback) {
        const ret = wasm.toriiclient_onTransaction(this.__wbg_ptr, isLikeNone(filter) ? 0 : addToExternrefTable0(filter), callback);
        return ret;
    }
    /**
     * Gets token information for the given contract addresses
     *
     * # Parameters
     * * `contract_addresses` - Array of contract addresses as hex strings
     * * `token_ids` - Array of token ids
     * * `limit` - Maximum number of tokens to return
     * * `cursor` - Cursor to start from
     *
     * # Returns
     * Result containing token information or error
     * @param {TokenQuery} query
     * @returns {Promise<Tokens>}
     */
    getTokens(query) {
        const ret = wasm.toriiclient_getTokens(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Subscribes to token updates
     *
     * # Parameters
     * * `contract_addresses` - Array of contract addresses as hex strings
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {string[] | null | undefined} contract_addresses
     * @param {WasmU256[] | null | undefined} token_ids
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onTokenUpdated(contract_addresses, token_ids, callback) {
        var ptr0 = isLikeNone(contract_addresses) ? 0 : passArrayJsValueToWasm0(contract_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        var ptr1 = isLikeNone(token_ids) ? 0 : passArrayJsValueToWasm0(token_ids, wasm.__wbindgen_malloc);
        var len1 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onTokenUpdated(this.__wbg_ptr, ptr0, len0, ptr1, len1, callback);
        return ret;
    }
    /**
     * Gets token balances for given accounts and contracts
     *
     * # Parameters
     * * `contract_addresses` - Array of contract addresses as hex strings
     * * `account_addresses` - Array of account addresses as hex strings
     * * `token_ids` - Array of token ids
     * * `limit` - Maximum number of token balances to return
     * * `cursor` - Cursor to start from
     *
     * # Returns
     * Result containing token balances or error
     * @param {TokenBalanceQuery} query
     * @returns {Promise<TokenBalances>}
     */
    getTokenBalances(query) {
        const ret = wasm.toriiclient_getTokenBalances(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Gets token contracts for given accounts and contracts
     *
     * # Parameters
     * * `contract_addresses` - Array of contract addresses as hex strings
     * * `account_addresses` - Array of account addresses as hex strings
     * * `token_ids` - Array of token ids
     * * `limit` - Maximum number of token balances to return
     * * `cursor` - Cursor to start from
     *
     * # Returns
     * Result containing token balances or error
     * @param {TokenContractQuery} query
     * @returns {Promise<TokenContracts>}
     */
    getTokenContracts(query) {
        const ret = wasm.toriiclient_getTokenContracts(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Gets token transfers for given accounts and contracts
     *
     * # Parameters
     * * `query` - TokenTransferQuery parameters
     *
     * # Returns
     * Result containing token transfers or error
     * @param {TokenTransferQuery} query
     * @returns {Promise<TokenTransfers>}
     */
    getTokenTransfers(query) {
        const ret = wasm.toriiclient_getTokenTransfers(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Gets aggregations (leaderboards, stats, rankings) matching query parameters
     *
     * # Parameters
     * * `query` - AggregationQuery containing aggregator_ids, entity_ids, and pagination
     *
     * # Returns
     * Result containing aggregations or error
     * @param {AggregationQuery} query
     * @returns {Promise<Aggregations>}
     */
    getAggregations(query) {
        const ret = wasm.toriiclient_getAggregations(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Retrieves achievements matching the query
     *
     * # Parameters
     * * `query` - AchievementQuery parameters
     *
     * # Returns
     * Result containing achievements or error
     * @param {AchievementQuery} query
     * @returns {Promise<Achievements>}
     */
    getAchievements(query) {
        const ret = wasm.toriiclient_getAchievements(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Retrieves player achievement data matching the query
     *
     * # Parameters
     * * `query` - PlayerAchievementQuery parameters
     *
     * # Returns
     * Result containing player achievements or error
     * @param {PlayerAchievementQuery} query
     * @returns {Promise<PlayerAchievements>}
     */
    getPlayerAchievements(query) {
        const ret = wasm.toriiclient_getPlayerAchievements(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Gets activities (user session tracking) matching query parameters
     *
     * # Parameters
     * * `query` - ActivityQuery containing world_addresses, namespaces, caller_addresses, and
     *   pagination
     *
     * # Returns
     * Result containing activities or error
     * @param {ActivityQuery} query
     * @returns {Promise<Activities>}
     */
    getActivities(query) {
        const ret = wasm.toriiclient_getActivities(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Queries entities based on the provided query parameters
     *
     * # Parameters
     * * `query` - Query parameters for filtering entities
     *
     * # Returns
     * Result containing matching entities or error
     * @param {Query} query
     * @returns {Promise<Entities>}
     */
    getEntities(query) {
        const ret = wasm.toriiclient_getEntities(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Gets all entities with pagination
     *
     * # Parameters
     * * `limit` - Maximum number of entities to return
     * * `cursor` - Cursor to start from
     *
     * # Returns
     * Result containing paginated entities or error
     * @param {number} limit
     * @param {string | null} [cursor]
     * @returns {Promise<Entities>}
     */
    getAllEntities(limit, cursor) {
        var ptr0 = isLikeNone(cursor) ? 0 : passStringToWasm0(cursor, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        var len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_getAllEntities(this.__wbg_ptr, limit, ptr0, len0);
        return ret;
    }
    /**
     * Gets event messages based on query parameters
     *
     * # Parameters
     * * `query` - Query parameters for filtering messages
     *
     * # Returns
     * Result containing matching event messages or error
     * @param {Query} query
     * @returns {Promise<Entities>}
     */
    getEventMessages(query) {
        const ret = wasm.toriiclient_getEventMessages(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Subscribes to entity updates
     *
     * # Parameters
     * * `clauses` - Array of key clauses for filtering updates
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {Clause | null | undefined} clause
     * @param {string[] | null | undefined} world_addresses
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onEntityUpdated(clause, world_addresses, callback) {
        var ptr0 = isLikeNone(world_addresses) ? 0 : passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onEntityUpdated(this.__wbg_ptr, isLikeNone(clause) ? 0 : addToExternrefTable0(clause), ptr0, len0, callback);
        return ret;
    }
    /**
     * Updates an existing entity subscription
     *
     * # Parameters
     * * `subscription` - Existing subscription to update
     * * `clauses` - New array of key clauses for filtering
     *
     * # Returns
     * Result containing unit or error
     * @param {Subscription} subscription
     * @param {Clause | null} [clause]
     * @param {string[] | null} [world_addresses]
     * @returns {Promise<void>}
     */
    updateEntitySubscription(subscription, clause, world_addresses) {
        _assertClass(subscription, Subscription);
        var ptr0 = isLikeNone(world_addresses) ? 0 : passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_updateEntitySubscription(this.__wbg_ptr, subscription.__wbg_ptr, isLikeNone(clause) ? 0 : addToExternrefTable0(clause), ptr0, len0);
        return ret;
    }
    /**
     * Subscribes to event message updates
     *
     * # Parameters
     * * `clauses` - Array of key clauses for filtering updates
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {Clause | null | undefined} clause
     * @param {string[] | null | undefined} world_addresses
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onEventMessageUpdated(clause, world_addresses, callback) {
        var ptr0 = isLikeNone(world_addresses) ? 0 : passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onEventMessageUpdated(this.__wbg_ptr, isLikeNone(clause) ? 0 : addToExternrefTable0(clause), ptr0, len0, callback);
        return ret;
    }
    /**
     * Updates an existing event message subscription
     *
     * # Parameters
     * * `subscription` - Existing subscription to update
     * * `clauses` - New array of key clauses for filtering
     *
     * # Returns
     * Result containing unit or error
     * @param {Subscription} subscription
     * @param {Clause | null} [clause]
     * @param {string[] | null} [world_addresses]
     * @returns {Promise<void>}
     */
    updateEventMessageSubscription(subscription, clause, world_addresses) {
        _assertClass(subscription, Subscription);
        var ptr0 = isLikeNone(world_addresses) ? 0 : passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_updateEventMessageSubscription(this.__wbg_ptr, subscription.__wbg_ptr, isLikeNone(clause) ? 0 : addToExternrefTable0(clause), ptr0, len0);
        return ret;
    }
    /**
     * Subscribes to Starknet events
     *
     * # Parameters
     * * `clauses` - Array of key clauses for filtering events
     * * `callback` - JavaScript function to call on events
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {KeysClause[]} clauses
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onStarknetEvent(clauses, callback) {
        const ptr0 = passArrayJsValueToWasm0(clauses, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onStarknetEvent(this.__wbg_ptr, ptr0, len0, callback);
        return ret;
    }
    /**
     * Subscribes to indexer updates
     *
     * # Parameters
     * * `contract_address` - Optional contract address to filter updates
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {string | null | undefined} contract_address
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onIndexerUpdated(contract_address, callback) {
        var ptr0 = isLikeNone(contract_address) ? 0 : passStringToWasm0(contract_address, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        var len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onIndexerUpdated(this.__wbg_ptr, ptr0, len0, callback);
        return ret;
    }
    /**
     * Subscribes to token balance updates
     *
     * # Parameters
     * * `contract_addresses` - Array of contract addresses to filter (empty for all)
     * * `account_addresses` - Array of account addresses to filter (empty for all)
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {string[] | null | undefined} contract_addresses
     * @param {string[] | null | undefined} account_addresses
     * @param {WasmU256[] | null | undefined} token_ids
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onTokenBalanceUpdated(contract_addresses, account_addresses, token_ids, callback) {
        var ptr0 = isLikeNone(contract_addresses) ? 0 : passArrayJsValueToWasm0(contract_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        var ptr1 = isLikeNone(account_addresses) ? 0 : passArrayJsValueToWasm0(account_addresses, wasm.__wbindgen_malloc);
        var len1 = WASM_VECTOR_LEN;
        var ptr2 = isLikeNone(token_ids) ? 0 : passArrayJsValueToWasm0(token_ids, wasm.__wbindgen_malloc);
        var len2 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onTokenBalanceUpdated(this.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2, callback);
        return ret;
    }
    /**
     * Updates an existing token balance subscription
     *
     * # Parameters
     * * `subscription` - Existing subscription to update
     * * `contract_addresses` - New array of contract addresses to filter
     * * `account_addresses` - New array of account addresses to filter
     *
     * # Returns
     * Result containing unit or error
     * @param {Subscription} subscription
     * @param {string[]} contract_addresses
     * @param {string[]} account_addresses
     * @param {WasmU256[]} token_ids
     * @returns {Promise<void>}
     */
    updateTokenBalanceSubscription(subscription, contract_addresses, account_addresses, token_ids) {
        _assertClass(subscription, Subscription);
        const ptr0 = passArrayJsValueToWasm0(contract_addresses, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passArrayJsValueToWasm0(account_addresses, wasm.__wbindgen_malloc);
        const len1 = WASM_VECTOR_LEN;
        const ptr2 = passArrayJsValueToWasm0(token_ids, wasm.__wbindgen_malloc);
        const len2 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_updateTokenBalanceSubscription(this.__wbg_ptr, subscription.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2);
        return ret;
    }
    /**
     * Subscribes to token transfer updates
     *
     * # Parameters
     * * `contract_addresses` - Array of contract addresses to filter (empty for all)
     * * `account_addresses` - Array of account addresses to filter (empty for all)
     * * `token_ids` - Array of token IDs to filter (empty for all)
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {string[] | null | undefined} contract_addresses
     * @param {string[] | null | undefined} account_addresses
     * @param {WasmU256[] | null | undefined} token_ids
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onTokenTransferUpdated(contract_addresses, account_addresses, token_ids, callback) {
        var ptr0 = isLikeNone(contract_addresses) ? 0 : passArrayJsValueToWasm0(contract_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        var ptr1 = isLikeNone(account_addresses) ? 0 : passArrayJsValueToWasm0(account_addresses, wasm.__wbindgen_malloc);
        var len1 = WASM_VECTOR_LEN;
        var ptr2 = isLikeNone(token_ids) ? 0 : passArrayJsValueToWasm0(token_ids, wasm.__wbindgen_malloc);
        var len2 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onTokenTransferUpdated(this.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2, callback);
        return ret;
    }
    /**
     * Subscribes to aggregation updates (leaderboards, stats, rankings)
     *
     * # Parameters
     * * `aggregator_ids` - Array of aggregator IDs to subscribe to
     * * `entity_ids` - Array of entity IDs to subscribe to
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {string[] | null | undefined} aggregator_ids
     * @param {string[] | null | undefined} entity_ids
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onAggregationUpdated(aggregator_ids, entity_ids, callback) {
        var ptr0 = isLikeNone(aggregator_ids) ? 0 : passArrayJsValueToWasm0(aggregator_ids, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        var ptr1 = isLikeNone(entity_ids) ? 0 : passArrayJsValueToWasm0(entity_ids, wasm.__wbindgen_malloc);
        var len1 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onAggregationUpdated(this.__wbg_ptr, ptr0, len0, ptr1, len1, callback);
        return ret;
    }
    /**
     * Subscribes to activity updates (user session tracking)
     *
     * # Parameters
     * * `world_addresses` - Array of world addresses to subscribe to
     * * `namespaces` - Array of namespaces to subscribe to
     * * `caller_addresses` - Array of caller addresses to subscribe to
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {string[] | null | undefined} world_addresses
     * @param {string[] | null | undefined} namespaces
     * @param {string[] | null | undefined} caller_addresses
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onActivityUpdated(world_addresses, namespaces, caller_addresses, callback) {
        var ptr0 = isLikeNone(world_addresses) ? 0 : passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        var ptr1 = isLikeNone(namespaces) ? 0 : passArrayJsValueToWasm0(namespaces, wasm.__wbindgen_malloc);
        var len1 = WASM_VECTOR_LEN;
        var ptr2 = isLikeNone(caller_addresses) ? 0 : passArrayJsValueToWasm0(caller_addresses, wasm.__wbindgen_malloc);
        var len2 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onActivityUpdated(this.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2, callback);
        return ret;
    }
    /**
     * Updates an existing token transfer subscription
     *
     * # Parameters
     * * `subscription` - Existing subscription to update
     * * `contract_addresses` - New array of contract addresses to filter
     * * `account_addresses` - New array of account addresses to filter
     * * `token_ids` - New array of token IDs to filter
     *
     * # Returns
     * Result containing unit or error
     * @param {Subscription} subscription
     * @param {string[]} contract_addresses
     * @param {string[]} account_addresses
     * @param {WasmU256[]} token_ids
     * @returns {Promise<void>}
     */
    updateTokenTransferSubscription(subscription, contract_addresses, account_addresses, token_ids) {
        _assertClass(subscription, Subscription);
        const ptr0 = passArrayJsValueToWasm0(contract_addresses, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passArrayJsValueToWasm0(account_addresses, wasm.__wbindgen_malloc);
        const len1 = WASM_VECTOR_LEN;
        const ptr2 = passArrayJsValueToWasm0(token_ids, wasm.__wbindgen_malloc);
        const len2 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_updateTokenTransferSubscription(this.__wbg_ptr, subscription.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2);
        return ret;
    }
    /**
     * Updates an existing aggregation subscription
     *
     * # Parameters
     * * `subscription` - Existing subscription to update
     * * `aggregator_ids` - New array of aggregator IDs to filter
     * * `entity_ids` - New array of entity IDs to filter
     *
     * # Returns
     * Result containing unit or error
     * @param {Subscription} subscription
     * @param {string[]} aggregator_ids
     * @param {string[]} entity_ids
     * @returns {Promise<void>}
     */
    updateAggregationSubscription(subscription, aggregator_ids, entity_ids) {
        _assertClass(subscription, Subscription);
        const ptr0 = passArrayJsValueToWasm0(aggregator_ids, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passArrayJsValueToWasm0(entity_ids, wasm.__wbindgen_malloc);
        const len1 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_updateAggregationSubscription(this.__wbg_ptr, subscription.__wbg_ptr, ptr0, len0, ptr1, len1);
        return ret;
    }
    /**
     * Subscribes to achievement progression updates
     *
     * # Parameters
     * * `world_addresses` - Optional array of world addresses as hex strings
     * * `namespaces` - Optional array of namespaces
     * * `player_addresses` - Optional array of player addresses as hex strings
     * * `achievement_ids` - Optional array of achievement IDs
     * * `callback` - JavaScript function to call on updates
     *
     * # Returns
     * Result containing subscription handle or error
     * @param {string[] | null | undefined} world_addresses
     * @param {string[] | null | undefined} namespaces
     * @param {string[] | null | undefined} player_addresses
     * @param {string[] | null | undefined} achievement_ids
     * @param {Function} callback
     * @returns {Promise<Subscription>}
     */
    onAchievementProgressionUpdated(world_addresses, namespaces, player_addresses, achievement_ids, callback) {
        var ptr0 = isLikeNone(world_addresses) ? 0 : passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        var len0 = WASM_VECTOR_LEN;
        var ptr1 = isLikeNone(namespaces) ? 0 : passArrayJsValueToWasm0(namespaces, wasm.__wbindgen_malloc);
        var len1 = WASM_VECTOR_LEN;
        var ptr2 = isLikeNone(player_addresses) ? 0 : passArrayJsValueToWasm0(player_addresses, wasm.__wbindgen_malloc);
        var len2 = WASM_VECTOR_LEN;
        var ptr3 = isLikeNone(achievement_ids) ? 0 : passArrayJsValueToWasm0(achievement_ids, wasm.__wbindgen_malloc);
        var len3 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_onAchievementProgressionUpdated(this.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3, callback);
        return ret;
    }
    /**
     * Updates achievement progression subscription
     *
     * # Parameters
     * * `subscription` - Existing subscription to update
     * * `world_addresses` - Array of world addresses
     * * `namespaces` - Array of namespaces
     * * `player_addresses` - Array of player addresses
     * * `achievement_ids` - Array of achievement IDs
     *
     * # Returns
     * Result containing unit or error
     * @param {Subscription} subscription
     * @param {string[]} world_addresses
     * @param {string[]} namespaces
     * @param {string[]} player_addresses
     * @param {string[]} achievement_ids
     * @returns {Promise<void>}
     */
    updateAchievementProgressionSubscription(subscription, world_addresses, namespaces, player_addresses, achievement_ids) {
        _assertClass(subscription, Subscription);
        const ptr0 = passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passArrayJsValueToWasm0(namespaces, wasm.__wbindgen_malloc);
        const len1 = WASM_VECTOR_LEN;
        const ptr2 = passArrayJsValueToWasm0(player_addresses, wasm.__wbindgen_malloc);
        const len2 = WASM_VECTOR_LEN;
        const ptr3 = passArrayJsValueToWasm0(achievement_ids, wasm.__wbindgen_malloc);
        const len3 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_updateAchievementProgressionSubscription(this.__wbg_ptr, subscription.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3);
        return ret;
    }
    /**
     * Updates an existing activity subscription
     *
     * # Parameters
     * * `subscription` - Existing subscription to update
     * * `world_addresses` - New array of world addresses to filter
     * * `namespaces` - New array of namespaces to filter
     * * `caller_addresses` - New array of caller addresses to filter
     *
     * # Returns
     * Result containing unit or error
     * @param {Subscription} subscription
     * @param {string[]} world_addresses
     * @param {string[]} namespaces
     * @param {string[]} caller_addresses
     * @returns {Promise<void>}
     */
    updateActivitySubscription(subscription, world_addresses, namespaces, caller_addresses) {
        _assertClass(subscription, Subscription);
        const ptr0 = passArrayJsValueToWasm0(world_addresses, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passArrayJsValueToWasm0(namespaces, wasm.__wbindgen_malloc);
        const len1 = WASM_VECTOR_LEN;
        const ptr2 = passArrayJsValueToWasm0(caller_addresses, wasm.__wbindgen_malloc);
        const len2 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_updateActivitySubscription(this.__wbg_ptr, subscription.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2);
        return ret;
    }
    /**
     * Perform a full-text search across indexed entities using FTS5.
     *
     * # Parameters
     * * `query` - Search query containing the search text and limit
     *
     * # Returns
     * A `SearchResponse` containing results grouped by table with relevance scores
     *
     * # Example
     * ```javascript
     * const results = await client.search({ query: "dragon", limit: 10 });
     * console.log(`Found ${results.total} total matches`);
     * for (const tableResults of results.results) {
     *     console.log(`Table ${tableResults.table}: ${tableResults.count} matches`);
     *     for (const match of tableResults.matches) {
     *         console.log(`  ID: ${match.id}, Score: ${match.score}`);
     *         for (const [field, value] of Object.entries(match.fields)) {
     *             console.log(`    ${field}: ${value}`);
     *         }
     *     }
     * }
     * ```
     * @param {SearchQuery} query
     * @returns {Promise<SearchResponse>}
     */
    search(query) {
        const ret = wasm.toriiclient_search(this.__wbg_ptr, query);
        return ret;
    }
    /**
     * Publishes a message to the network
     *
     * # Parameters
     * * `message` - Message to publish as JSON string
     * * `signature` - Array of signature field elements as hex strings
     *
     * # Returns
     * Result containing entity id of the offchain message or error
     * @param {Message} message
     * @returns {Promise<string>}
     */
    publishMessage(message) {
        const ret = wasm.toriiclient_publishMessage(this.__wbg_ptr, message);
        return ret;
    }
    /**
     * Publishes multiple messages to the network
     *
     * # Parameters
     * * `messages` - Array of Message objects, each containing message and signature fields
     *
     * # Returns
     * Result containing array of entity ids of the offchain messages or error
     * @param {Message[]} messages
     * @returns {Promise<string[]>}
     */
    publishMessageBatch(messages) {
        const ptr0 = passArrayJsValueToWasm0(messages, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.toriiclient_publishMessageBatch(this.__wbg_ptr, ptr0, len0);
        return ret;
    }
}
if (Symbol.dispose) ToriiClient.prototype[Symbol.dispose] = ToriiClient.prototype.free;

const TypedDataFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_typeddata_free(ptr >>> 0, 1));

export class TypedData {

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        TypedDataFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_typeddata_free(ptr, 0);
    }
    /**
     * @param {string} typed_data
     */
    constructor(typed_data) {
        const ptr0 = passStringToWasm0(typed_data, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.typeddata_new(ptr0, len0);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        this.__wbg_ptr = ret[0] >>> 0;
        TypedDataFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * Encodes typed data according to Starknet's typed data specification
     *
     * # Parameters
     * * `typed_data` - JSON string containing the typed data
     * * `address` - Address as hex string
     *
     * # Returns
     * Result containing encoded data as hex string or error
     * @param {string} address
     * @returns {string}
     */
    encode(address) {
        let deferred3_0;
        let deferred3_1;
        try {
            const ptr0 = passStringToWasm0(address, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
            const len0 = WASM_VECTOR_LEN;
            const ret = wasm.typeddata_encode(this.__wbg_ptr, ptr0, len0);
            var ptr2 = ret[0];
            var len2 = ret[1];
            if (ret[3]) {
                ptr2 = 0; len2 = 0;
                throw takeFromExternrefTable0(ret[2]);
            }
            deferred3_0 = ptr2;
            deferred3_1 = len2;
            return getStringFromWasm0(ptr2, len2);
        } finally {
            wasm.__wbindgen_free(deferred3_0, deferred3_1, 1);
        }
    }
}
if (Symbol.dispose) TypedData.prototype[Symbol.dispose] = TypedData.prototype.free;

const VerifyingKeyFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_verifyingkey_free(ptr >>> 0, 1));

export class VerifyingKey {

    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(VerifyingKey.prototype);
        obj.__wbg_ptr = ptr;
        VerifyingKeyFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }

    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        VerifyingKeyFinalization.unregister(this);
        return ptr;
    }

    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_verifyingkey_free(ptr, 0);
    }
    /**
     * Initializes a new verifying key from a scalar
     *
     * # Parameters
     * * `verifying_key` - Verifying key as hex string
     *
     * # Returns
     * Result containing verifying key or error
     * @param {string} verifying_key
     */
    constructor(verifying_key) {
        const ptr0 = passStringToWasm0(verifying_key, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.verifyingkey_new(ptr0, len0);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        this.__wbg_ptr = ret[0] >>> 0;
        VerifyingKeyFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * Returns the scalar of the verifying key
     *
     * # Returns
     * Result containing scalar as hex string or error
     * @returns {string}
     */
    scalar() {
        let deferred2_0;
        let deferred2_1;
        try {
            const ret = wasm.verifyingkey_scalar(this.__wbg_ptr);
            var ptr1 = ret[0];
            var len1 = ret[1];
            if (ret[3]) {
                ptr1 = 0; len1 = 0;
                throw takeFromExternrefTable0(ret[2]);
            }
            deferred2_0 = ptr1;
            deferred2_1 = len1;
            return getStringFromWasm0(ptr1, len1);
        } finally {
            wasm.__wbindgen_free(deferred2_0, deferred2_1, 1);
        }
    }
    /**
     * Verifies a signature against a message hash using a verifying key
     *
     * # Parameters
     * * `verifying_key` - Verifying key as hex string
     * * `hash` - Message hash as hex string
     * * `signature` - Signature to verify
     *
     * # Returns
     * Result containing verification success boolean or error
     * @param {string} hash
     * @param {Signature} signature
     * @returns {boolean}
     */
    verify(hash, signature) {
        const ptr = this.__destroy_into_raw();
        const ptr0 = passStringToWasm0(hash, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.verifyingkey_verify(ptr, ptr0, len0, signature);
        if (ret[2]) {
            throw takeFromExternrefTable0(ret[1]);
        }
        return ret[0] !== 0;
    }
}
if (Symbol.dispose) VerifyingKey.prototype[Symbol.dispose] = VerifyingKey.prototype.free;

export function __wbg_Error_e17e777aac105295(arg0, arg1) {
    const ret = Error(getStringFromWasm0(arg0, arg1));
    return ret;
};

export function __wbg_Number_998bea33bd87c3e0(arg0) {
    const ret = Number(arg0);
    return ret;
};

export function __wbg_String_8f0eb39a4a4c2f66(arg0, arg1) {
    const ret = String(arg1);
    const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
    getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
};

export function __wbg_abort_67e1b49bf6614565(arg0) {
    arg0.abort();
};

export function __wbg_abort_d830bf2e9aa6ec5b(arg0, arg1) {
    arg0.abort(arg1);
};

export function __wbg_account_new(arg0) {
    const ret = Account.__wrap(arg0);
    return ret;
};

export function __wbg_append_72a3c0addd2bce38() { return handleError(function (arg0, arg1, arg2, arg3, arg4) {
    arg0.append(getStringFromWasm0(arg1, arg2), getStringFromWasm0(arg3, arg4));
}, arguments) };

export function __wbg_body_4851aa049324a851(arg0) {
    const ret = arg0.body;
    return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
};

export function __wbg_buffer_8d40b1d762fb3c66(arg0) {
    const ret = arg0.buffer;
    return ret;
};

export function __wbg_byobRequest_2c036bceca1e6037(arg0) {
    const ret = arg0.byobRequest;
    return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
};

export function __wbg_byteLength_331a6b5545834024(arg0) {
    const ret = arg0.byteLength;
    return ret;
};

export function __wbg_byteOffset_49a5b5608000358b(arg0) {
    const ret = arg0.byteOffset;
    return ret;
};

export function __wbg_call_13410aac570ffff7() { return handleError(function (arg0, arg1) {
    const ret = arg0.call(arg1);
    return ret;
}, arguments) };

export function __wbg_call_a5400b25a865cfd8() { return handleError(function (arg0, arg1, arg2) {
    const ret = arg0.call(arg1, arg2);
    return ret;
}, arguments) };

export function __wbg_cancel_8bb5b8f4906b658a(arg0) {
    const ret = arg0.cancel();
    return ret;
};

export function __wbg_catch_c80ecae90cb8ed4e(arg0, arg1) {
    const ret = arg0.catch(arg1);
    return ret;
};

export function __wbg_clearTimeout_5a54f8841c30079a(arg0) {
    const ret = clearTimeout(arg0);
    return ret;
};

export function __wbg_clearTimeout_7a42b49784aea641(arg0) {
    const ret = clearTimeout(arg0);
    return ret;
};

export function __wbg_close_cccada6053ee3a65() { return handleError(function (arg0) {
    arg0.close();
}, arguments) };

export function __wbg_close_d71a78219dc23e91() { return handleError(function (arg0) {
    arg0.close();
}, arguments) };

export function __wbg_crypto_574e78ad8b13b65f(arg0) {
    const ret = arg0.crypto;
    return ret;
};

export function __wbg_done_75ed0ee6dd243d9d(arg0) {
    const ret = arg0.done;
    return ret;
};

export function __wbg_enqueue_452bc2343d1c2ff9() { return handleError(function (arg0, arg1) {
    arg0.enqueue(arg1);
}, arguments) };

export function __wbg_entries_2be2f15bd5554996(arg0) {
    const ret = Object.entries(arg0);
    return ret;
};

export function __wbg_error_7534b8e9a36f1ab4(arg0, arg1) {
    let deferred0_0;
    let deferred0_1;
    try {
        deferred0_0 = arg0;
        deferred0_1 = arg1;
        console.error(getStringFromWasm0(arg0, arg1));
    } finally {
        wasm.__wbindgen_free(deferred0_0, deferred0_1, 1);
    }
};

export function __wbg_fetch_36d024dbd9192353(arg0, arg1, arg2) {
    const ret = arg0.fetch(arg1, arg2);
    return ret;
};

export function __wbg_fetch_74a3e84ebd2c9a0e(arg0) {
    const ret = fetch(arg0);
    return ret;
};

export function __wbg_fetch_769f3df592e37b75(arg0, arg1) {
    const ret = fetch(arg0, arg1);
    return ret;
};

export function __wbg_fetch_87aed7f306ec6d63(arg0, arg1) {
    const ret = arg0.fetch(arg1);
    return ret;
};

export function __wbg_getRandomValues_b8f5dbd5f3995a9e() { return handleError(function (arg0, arg1) {
    arg0.getRandomValues(arg1);
}, arguments) };

export function __wbg_getReader_48e00749fe3f6089() { return handleError(function (arg0) {
    const ret = arg0.getReader();
    return ret;
}, arguments) };

export function __wbg_getTime_6bb3f64e0f18f817(arg0) {
    const ret = arg0.getTime();
    return ret;
};

export function __wbg_get_0da715ceaecea5c8(arg0, arg1) {
    const ret = arg0[arg1 >>> 0];
    return ret;
};

export function __wbg_get_458e874b43b18b25() { return handleError(function (arg0, arg1) {
    const ret = Reflect.get(arg0, arg1);
    return ret;
}, arguments) };

export function __wbg_getdone_f026246f6bbe58d3(arg0) {
    const ret = arg0.done;
    return isLikeNone(ret) ? 0xFFFFFF : ret ? 1 : 0;
};

export function __wbg_getvalue_31e5a08f61e5aa42(arg0) {
    const ret = arg0.value;
    return ret;
};

export function __wbg_getwithrefkey_1dc361bd10053bfe(arg0, arg1) {
    const ret = arg0[arg1];
    return ret;
};

export function __wbg_has_b89e451f638123e3() { return handleError(function (arg0, arg1) {
    const ret = Reflect.has(arg0, arg1);
    return ret;
}, arguments) };

export function __wbg_headers_29fec3c72865cd75(arg0) {
    const ret = arg0.headers;
    return ret;
};

export function __wbg_instanceof_ArrayBuffer_67f3012529f6a2dd(arg0) {
    let result;
    try {
        result = arg0 instanceof ArrayBuffer;
    } catch (_) {
        result = false;
    }
    const ret = result;
    return ret;
};

export function __wbg_instanceof_Response_50fde2cd696850bf(arg0) {
    let result;
    try {
        result = arg0 instanceof Response;
    } catch (_) {
        result = false;
    }
    const ret = result;
    return ret;
};

export function __wbg_instanceof_Uint8Array_9a8378d955933db7(arg0) {
    let result;
    try {
        result = arg0 instanceof Uint8Array;
    } catch (_) {
        result = false;
    }
    const ret = result;
    return ret;
};

export function __wbg_isArray_030cce220591fb41(arg0) {
    const ret = Array.isArray(arg0);
    return ret;
};

export function __wbg_isSafeInteger_1c0d1af5542e102a(arg0) {
    const ret = Number.isSafeInteger(arg0);
    return ret;
};

export function __wbg_iterator_f370b34483c71a1c() {
    const ret = Symbol.iterator;
    return ret;
};

export function __wbg_length_186546c51cd61acd(arg0) {
    const ret = arg0.length;
    return ret;
};

export function __wbg_length_6bb7e81f9d7713e4(arg0) {
    const ret = arg0.length;
    return ret;
};

export function __wbg_msCrypto_a61aeb35a24c1329(arg0) {
    const ret = arg0.msCrypto;
    return ret;
};

export function __wbg_new0_b0a0a38c201e6df5() {
    const ret = new Date();
    return ret;
};

export function __wbg_new_19c25a3f2fa63a02() {
    const ret = new Object();
    return ret;
};

export function __wbg_new_1f3a344cf3123716() {
    const ret = new Array();
    return ret;
};

export function __wbg_new_2e3c58a15f39f5f9(arg0, arg1) {
    try {
        var state0 = {a: arg0, b: arg1};
        var cb0 = (arg0, arg1) => {
            const a = state0.a;
            state0.a = 0;
            try {
                return __wbg_adapter_283(a, state0.b, arg0, arg1);
            } finally {
                state0.a = a;
            }
        };
        const ret = new Promise(cb0);
        return ret;
    } finally {
        state0.a = state0.b = 0;
    }
};

export function __wbg_new_2ff1f68f3676ea53() {
    const ret = new Map();
    return ret;
};

export function __wbg_new_638ebfaedbf32a5e(arg0) {
    const ret = new Uint8Array(arg0);
    return ret;
};

export function __wbg_new_66b9434b4e59b63e() { return handleError(function () {
    const ret = new AbortController();
    return ret;
}, arguments) };

export function __wbg_new_8a6f238a6ece86ea() {
    const ret = new Error();
    return ret;
};

export function __wbg_new_da9dc54c5db29dfa(arg0, arg1) {
    const ret = new Error(getStringFromWasm0(arg0, arg1));
    return ret;
};

export function __wbg_new_f6e53210afea8e45() { return handleError(function () {
    const ret = new Headers();
    return ret;
}, arguments) };

export function __wbg_newfromslice_074c56947bd43469(arg0, arg1) {
    const ret = new Uint8Array(getArrayU8FromWasm0(arg0, arg1));
    return ret;
};

export function __wbg_newnoargs_254190557c45b4ec(arg0, arg1) {
    const ret = new Function(getStringFromWasm0(arg0, arg1));
    return ret;
};

export function __wbg_newwithbyteoffsetandlength_e8f53910b4d42b45(arg0, arg1, arg2) {
    const ret = new Uint8Array(arg0, arg1 >>> 0, arg2 >>> 0);
    return ret;
};

export function __wbg_newwithlength_a167dcc7aaa3ba77(arg0) {
    const ret = new Uint8Array(arg0 >>> 0);
    return ret;
};

export function __wbg_newwithstrandinit_b5d168a29a3fd85f() { return handleError(function (arg0, arg1, arg2) {
    const ret = new Request(getStringFromWasm0(arg0, arg1), arg2);
    return ret;
}, arguments) };

export function __wbg_next_5b3530e612fde77d(arg0) {
    const ret = arg0.next;
    return ret;
};

export function __wbg_next_692e82279131b03c() { return handleError(function (arg0) {
    const ret = arg0.next();
    return ret;
}, arguments) };

export function __wbg_node_905d3e251edff8a2(arg0) {
    const ret = arg0.node;
    return ret;
};

export function __wbg_parse_442f5ba02e5eaf8b() { return handleError(function (arg0, arg1) {
    const ret = JSON.parse(getStringFromWasm0(arg0, arg1));
    return ret;
}, arguments) };

export function __wbg_process_dc0fbacc7c1c06f7(arg0) {
    const ret = arg0.process;
    return ret;
};

export function __wbg_prototypesetcall_3d4a26c1ed734349(arg0, arg1, arg2) {
    Uint8Array.prototype.set.call(getArrayU8FromWasm0(arg0, arg1), arg2);
};

export function __wbg_push_330b2eb93e4e1212(arg0, arg1) {
    const ret = arg0.push(arg1);
    return ret;
};

export function __wbg_queueMicrotask_25d0739ac89e8c88(arg0) {
    queueMicrotask(arg0);
};

export function __wbg_queueMicrotask_4488407636f5bf24(arg0) {
    const ret = arg0.queueMicrotask;
    return ret;
};

export function __wbg_randomFillSync_ac0988aba3254290() { return handleError(function (arg0, arg1) {
    arg0.randomFillSync(arg1);
}, arguments) };

export function __wbg_read_bc925c758aa4d897(arg0) {
    const ret = arg0.read();
    return ret;
};

export function __wbg_releaseLock_ff29b586502a8221(arg0) {
    arg0.releaseLock();
};

export function __wbg_require_60cc747a6bc5215a() { return handleError(function () {
    const ret = module.require;
    return ret;
}, arguments) };

export function __wbg_resolve_4055c623acdd6a1b(arg0) {
    const ret = Promise.resolve(arg0);
    return ret;
};

export function __wbg_respond_6c2c4e20ef85138e() { return handleError(function (arg0, arg1) {
    arg0.respond(arg1 >>> 0);
}, arguments) };

export function __wbg_setTimeout_7bb3429662ab1e70(arg0, arg1) {
    const ret = setTimeout(arg0, arg1);
    return ret;
};

export function __wbg_setTimeout_db2dbaeefb6f39c7() { return handleError(function (arg0, arg1) {
    const ret = setTimeout(arg0, arg1);
    return ret;
}, arguments) };

export function __wbg_set_1353b2a5e96bc48c(arg0, arg1, arg2) {
    arg0.set(getArrayU8FromWasm0(arg1, arg2));
};

export function __wbg_set_3f1d0b984ed272ed(arg0, arg1, arg2) {
    arg0[arg1] = arg2;
};

export function __wbg_set_453345bcda80b89a() { return handleError(function (arg0, arg1, arg2) {
    const ret = Reflect.set(arg0, arg1, arg2);
    return ret;
}, arguments) };

export function __wbg_set_90f6c0f7bd8c0415(arg0, arg1, arg2) {
    arg0[arg1 >>> 0] = arg2;
};

export function __wbg_set_b7f1cf4fae26fe2a(arg0, arg1, arg2) {
    const ret = arg0.set(arg1, arg2);
    return ret;
};

export function __wbg_setbody_c8460bdf44147df8(arg0, arg1) {
    arg0.body = arg1;
};

export function __wbg_setcache_90ca4ad8a8ad40d3(arg0, arg1) {
    arg0.cache = __wbindgen_enum_RequestCache[arg1];
};

export function __wbg_setcredentials_9cd60d632c9d5dfc(arg0, arg1) {
    arg0.credentials = __wbindgen_enum_RequestCredentials[arg1];
};

export function __wbg_setheaders_0052283e2f3503d1(arg0, arg1) {
    arg0.headers = arg1;
};

export function __wbg_setintegrity_de8bf847597602b5(arg0, arg1, arg2) {
    arg0.integrity = getStringFromWasm0(arg1, arg2);
};

export function __wbg_setmethod_9b504d5b855b329c(arg0, arg1, arg2) {
    arg0.method = getStringFromWasm0(arg1, arg2);
};

export function __wbg_setmode_a23e1a2ad8b512f8(arg0, arg1) {
    arg0.mode = __wbindgen_enum_RequestMode[arg1];
};

export function __wbg_setredirect_9542307f3ab946a9(arg0, arg1) {
    arg0.redirect = __wbindgen_enum_RequestRedirect[arg1];
};

export function __wbg_setreferrer_c8dd38f95f31e178(arg0, arg1, arg2) {
    arg0.referrer = getStringFromWasm0(arg1, arg2);
};

export function __wbg_setreferrerpolicy_164abad8ed6e3886(arg0, arg1) {
    arg0.referrerPolicy = __wbindgen_enum_ReferrerPolicy[arg1];
};

export function __wbg_setsignal_8c45ad1247a74809(arg0, arg1) {
    arg0.signal = arg1;
};

export function __wbg_signal_da4d466ce86118b5(arg0) {
    const ret = arg0.signal;
    return ret;
};

export function __wbg_stack_0ed75d68575b0f3c(arg0, arg1) {
    const ret = arg1.stack;
    const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
    getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
};

export function __wbg_static_accessor_GLOBAL_8921f820c2ce3f12() {
    const ret = typeof global === 'undefined' ? null : global;
    return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
};

export function __wbg_static_accessor_GLOBAL_THIS_f0a4409105898184() {
    const ret = typeof globalThis === 'undefined' ? null : globalThis;
    return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
};

export function __wbg_static_accessor_SELF_995b214ae681ff99() {
    const ret = typeof self === 'undefined' ? null : self;
    return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
};

export function __wbg_static_accessor_WINDOW_cde3890479c675ea() {
    const ret = typeof window === 'undefined' ? null : window;
    return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
};

export function __wbg_status_3fea3036088621d6(arg0) {
    const ret = arg0.status;
    return ret;
};

export function __wbg_stringify_b98c93d0a190446a() { return handleError(function (arg0) {
    const ret = JSON.stringify(arg0);
    return ret;
}, arguments) };

export function __wbg_subarray_70fd07feefe14294(arg0, arg1, arg2) {
    const ret = arg0.subarray(arg1 >>> 0, arg2 >>> 0);
    return ret;
};

export function __wbg_subscription_new(arg0) {
    const ret = Subscription.__wrap(arg0);
    return ret;
};

export function __wbg_text_0f69a215637b9b34() { return handleError(function (arg0) {
    const ret = arg0.text();
    return ret;
}, arguments) };

export function __wbg_then_b33a773d723afa3e(arg0, arg1, arg2) {
    const ret = arg0.then(arg1, arg2);
    return ret;
};

export function __wbg_then_e22500defe16819f(arg0, arg1) {
    const ret = arg0.then(arg1);
    return ret;
};

export function __wbg_toString_78df35411a4fd40c(arg0) {
    const ret = arg0.toString();
    return ret;
};

export function __wbg_toriiclient_new(arg0) {
    const ret = ToriiClient.__wrap(arg0);
    return ret;
};

export function __wbg_url_e5720dfacf77b05e(arg0, arg1) {
    const ret = arg1.url;
    const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
    getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
};

export function __wbg_value_dd9372230531eade(arg0) {
    const ret = arg0.value;
    return ret;
};

export function __wbg_versions_c01dfd4722a88165(arg0) {
    const ret = arg0.versions;
    return ret;
};

export function __wbg_view_91cc97d57ab30530(arg0) {
    const ret = arg0.view;
    return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
};

export function __wbg_wbindgenbigintgetasi64_ac743ece6ab9bba1(arg0, arg1) {
    const v = arg1;
    const ret = typeof(v) === 'bigint' ? v : undefined;
    getDataViewMemory0().setBigInt64(arg0 + 8 * 1, isLikeNone(ret) ? BigInt(0) : ret, true);
    getDataViewMemory0().setInt32(arg0 + 4 * 0, !isLikeNone(ret), true);
};

export function __wbg_wbindgenbooleanget_3fe6f642c7d97746(arg0) {
    const v = arg0;
    const ret = typeof(v) === 'boolean' ? v : undefined;
    return isLikeNone(ret) ? 0xFFFFFF : ret ? 1 : 0;
};

export function __wbg_wbindgencbdrop_eb10308566512b88(arg0) {
    const obj = arg0.original;
    if (obj.cnt-- == 1) {
        obj.a = 0;
        return true;
    }
    const ret = false;
    return ret;
};

export function __wbg_wbindgendebugstring_99ef257a3ddda34d(arg0, arg1) {
    const ret = debugString(arg1);
    const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
    getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
};

export function __wbg_wbindgenin_d7a1ee10933d2d55(arg0, arg1) {
    const ret = arg0 in arg1;
    return ret;
};

export function __wbg_wbindgenisbigint_ecb90cc08a5a9154(arg0) {
    const ret = typeof(arg0) === 'bigint';
    return ret;
};

export function __wbg_wbindgenisfunction_8cee7dce3725ae74(arg0) {
    const ret = typeof(arg0) === 'function';
    return ret;
};

export function __wbg_wbindgenisobject_307a53c6bd97fbf8(arg0) {
    const val = arg0;
    const ret = typeof(val) === 'object' && val !== null;
    return ret;
};

export function __wbg_wbindgenisstring_d4fa939789f003b0(arg0) {
    const ret = typeof(arg0) === 'string';
    return ret;
};

export function __wbg_wbindgenisundefined_c4b71d073b92f3c5(arg0) {
    const ret = arg0 === undefined;
    return ret;
};

export function __wbg_wbindgenjsvaleq_e6f2ad59ccae1b58(arg0, arg1) {
    const ret = arg0 === arg1;
    return ret;
};

export function __wbg_wbindgenjsvallooseeq_9bec8c9be826bed1(arg0, arg1) {
    const ret = arg0 == arg1;
    return ret;
};

export function __wbg_wbindgennumberget_f74b4c7525ac05cb(arg0, arg1) {
    const obj = arg1;
    const ret = typeof(obj) === 'number' ? obj : undefined;
    getDataViewMemory0().setFloat64(arg0 + 8 * 1, isLikeNone(ret) ? 0 : ret, true);
    getDataViewMemory0().setInt32(arg0 + 4 * 0, !isLikeNone(ret), true);
};

export function __wbg_wbindgenstringget_0f16a6ddddef376f(arg0, arg1) {
    const obj = arg1;
    const ret = typeof(obj) === 'string' ? obj : undefined;
    var ptr1 = isLikeNone(ret) ? 0 : passStringToWasm0(ret, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    var len1 = WASM_VECTOR_LEN;
    getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
    getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
};

export function __wbg_wbindgenthrow_451ec1a8469d7eb6(arg0, arg1) {
    throw new Error(getStringFromWasm0(arg0, arg1));
};

export function __wbindgen_cast_2241b6af4c4b2941(arg0, arg1) {
    // Cast intrinsic for `Ref(String) -> Externref`.
    const ret = getStringFromWasm0(arg0, arg1);
    return ret;
};

export function __wbindgen_cast_25a0a844437d0e92(arg0, arg1) {
    var v0 = getArrayJsValueFromWasm0(arg0, arg1).slice();
    wasm.__wbindgen_free(arg0, arg1 * 4, 4);
    // Cast intrinsic for `Vector(NamedExternref("string")) -> Externref`.
    const ret = v0;
    return ret;
};

export function __wbindgen_cast_27024fac1bcd0f4d(arg0, arg1) {
    // Cast intrinsic for `Closure(Closure { dtor_idx: 1098, function: Function { arguments: [], shim_idx: 1099, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
    const ret = makeMutClosure(arg0, arg1, 1098, __wbg_adapter_8);
    return ret;
};

export function __wbindgen_cast_4625c577ab2ec9ee(arg0) {
    // Cast intrinsic for `U64 -> Externref`.
    const ret = BigInt.asUintN(64, arg0);
    return ret;
};

export function __wbindgen_cast_5909bf2a9c05b767(arg0, arg1) {
    // Cast intrinsic for `Closure(Closure { dtor_idx: 1119, function: Function { arguments: [Externref], shim_idx: 1120, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
    const ret = makeMutClosure(arg0, arg1, 1119, __wbg_adapter_15);
    return ret;
};

export function __wbindgen_cast_9ae0607507abb057(arg0) {
    // Cast intrinsic for `I64 -> Externref`.
    const ret = arg0;
    return ret;
};

export function __wbindgen_cast_cb9088102bce6b30(arg0, arg1) {
    // Cast intrinsic for `Ref(Slice(U8)) -> NamedExternref("Uint8Array")`.
    const ret = getArrayU8FromWasm0(arg0, arg1);
    return ret;
};

export function __wbindgen_cast_d2bb9f8831250295(arg0, arg1) {
    // Cast intrinsic for `Closure(Closure { dtor_idx: 747, function: Function { arguments: [], shim_idx: 748, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
    const ret = makeMutClosure(arg0, arg1, 747, __wbg_adapter_24);
    return ret;
};

export function __wbindgen_cast_d6cd19b81560fd6e(arg0) {
    // Cast intrinsic for `F64 -> Externref`.
    const ret = arg0;
    return ret;
};

export function __wbindgen_init_externref_table() {
    const table = wasm.__wbindgen_export_4;
    const offset = table.grow(4);
    table.set(0, undefined);
    table.set(offset + 0, undefined);
    table.set(offset + 1, null);
    table.set(offset + 2, true);
    table.set(offset + 3, false);
    ;
};

