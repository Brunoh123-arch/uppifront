const _log = (fn, ...rest) => { if (window.__loggingEnabled) console.log(fn(), ...rest); };
const _warn = (fn, ...rest) => { if (window.__loggingEnabled) console.warn(fn(), ...rest); };
const _error = (fn, ...rest) => { if (window.__loggingEnabled) console.error(fn(), ...rest); };

_log(() => '[QuarkBridge] Script loading started');

if (typeof window.__quarkCommandExecutor !== 'undefined') {
    _warn(() => '[QuarkBridge] Bridge already initialized. Skipping reinitialization.');
} else {

    /**
     * Sends event to Android handler with proper data formatting
     * @param {string} type - Event type identifier
     * @param {Object} payload - Data payload (will be stringified to JSON)
     */
    function sendEventToAndroid(type, payload) {
        const eventType = String(type);
        let payloadString;
        try {
            payloadString = JSON.stringify(payload);
        } catch (error) {
            _error(() => '[QuarkBridge] Payload serialization error:', error);
            return;
        }
        _log(() => `[QuarkBridge] Attempting to send event: ${eventType}`, payload);
        if (!window.__quarkEventHandler) {
            _warn(() => '[QuarkBridge] __quarkEventHandler not defined');
            return;
        }
        if (typeof window.__quarkEventHandler.handleEvent !== 'function') {
            _warn(() => '[QuarkBridge] __quarkEventHandler.handleEvent is not a function');
            return;
        }
        try {
            window.__quarkEventHandler.handleEvent(eventType, payloadString);
            _log(() => `[QuarkBridge] Event "${eventType}" sent successfully`);
        } catch (error) {
            _error(() => `[QuarkBridge] Error sending event "${eventType}":`, error);
        }
    }

    window.__quarkCommandExecutor = (function() {

        const commandHandlers = {};

        return {
            /**
             * Registers a handler for a specific command type
             * @param {string} commandType - The type of command to handle
             * @param {Function} handler - Callback function to execute for this command type
             */
            registerHandler: function(commandType, handler) {
                if (typeof handler !== 'function') {
                    _error(() => `[QuarkBridge] Invalid handler for command: ${commandType}`);
                    return;
                }

                commandHandlers[commandType] = handler;
                _log(() => `[QuarkBridge] Handler registered for: ${commandType}`);
            },

            /**
             * Executes a command with the given type and payload
             * @param {string} type - The type of command to execute
             * @param {string} payloadJson - Command data as JSON string
             */
            executeCommand: function(type, payloadJson) {
                _log(() => `[QuarkBridge] Received command: type=${type}, payload=${payloadJson}`);

                try {
                    const payload = payloadJson ? JSON.parse(payloadJson) : null;
                    const handler = commandHandlers[type];

                    if (handler) {
                        handler(payload);
                        _log(() => `[QuarkBridge] Command "${type}" handled successfully`);
                    } else {
                        _warn(() => `[QuarkBridge] No handler registered for command: ${type}`);
                    }
                } catch (error) {
                    _error(() => `[QuarkBridge] Error processing command "${type}":`, error);
                }
            }
        };
    })();

    window.__quarkCommandExecutor.registerHandler('handleWebDirective', (payload) => {
        const convertedData = __convertPlatformDataToData(payload.directiveData);
        if (!convertedData) {
            _error(() => `Failed to handle web directive ${payload.directiveName}: data invalid`);
            return;
        }
        try {
            window.yandex.quarkNative.__handleWebCapabilityDirective(payload.capabilityId, {
                name: payload.directiveName,
                data: convertedData
            });
            _log(() => `[QuarkBridge] Web directive ${payload.directiveName} success handled`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to handle web directive ${payload.directiveName}`, error);
        }
    });

    function __base64ToArrayBuffer(base64) {
        const binary = atob(base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        return bytes.buffer;
    }

    function __convertPlatformDataToData(data) {
        if (!data?.type || !data?.value) {
            _error(() => `[QuarkBridge] Failed to convert invalid platform data to js data`);
            return null;
        }
        let dataValue = '';
        let dataType = data.type;
        try {
            switch (dataType) {
                case 'json':
                    dataValue = JSON.parse(data.value);
                    break;
                case 'protobuf':
                    dataValue = __base64ToArrayBuffer(data.value);
                    break;
                default:
                    _error(() => `[QuarkBridge] Unsupported data type: ${dataType}`);
                    return null;
            }
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to deserialize platform data body:`, error);
            return null;
        }
        return {
            type: dataType,
            value: dataValue
        };
    }

    window.__quarkCommandExecutor.registerHandler('registerPlatformCapability', (payload) => {
        if (!payload?.capabilityId) {
            _error(() => '[QuarkBridge] Invalid payload: capabilityId is required');
            return;
        }

        const initialState = payload.initialState || {};
        let currentState = __convertPlatformDataToData(initialState) || {
            type: 'json',
            value: {}
        };
        const stateListeners = [];
        const capabilityId = payload.capabilityId;
        const platformCapability = {
            id: capabilityId,

            supportedDirectives: payload.supportedDirectives || [],

            isPlatformCapability: true,

            local: payload.isLocal,

            get state() {
                return currentState;
            },

            callDirective: function(directive, options) {
                try {
                    window.yandex.quarkNative.callDirective(capabilityId, directive);
                } catch (error) {
                    _error(() => `[QuarkBridge] Error calling directive:`, error);
                }
            },

            addStateListener: function(callback) {
                if (!stateListeners.includes(callback)) {
                    stateListeners.push(callback);
                    try {
                        callback(currentState);
                    } catch (error) {
                        _error(() => `[QuarkBridge] Error calling state listener:`, error);
                    }
                }
            },

            removeStateListener: function(callback) {
                const index = stateListeners.indexOf(callback);
                if (index !== -1) {
                    stateListeners.splice(index, 1);
                }
            },

            __updateState: function(newState) {
                currentState = newState;
                stateListeners.forEach(listener => {
                    try {
                        listener(currentState);
                    } catch (error) {
                        _error(() => `[QuarkBridge] Error notifying listener:`, error);
                    }
                });
            }
        };

        try {
            window.yandex.quarkNative.__addPlatformCapability(platformCapability);
            _log(() => `[QuarkBridge] Registered platform capability: ${capabilityId}`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to register capability ${capabilityId}:`, error);
        }
    });

    window.__quarkCommandExecutor.registerHandler('unregisterPlatformCapability', (payload) => {
        if (!payload?.capabilityId) {
            _error(() => '[QuarkBridge] Invalid payload: capabilityId is required');
            return;
        }

        try {
            window.yandex.quarkNative.__removePlatformCapability(payload.capabilityId);
            _log(() => `[QuarkBridge] Unregister platform capability ${payload.capabilityId} success handled`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to unregister capability ${payload.capabilityId}`, error);
        }
    });

    window.__quarkCommandExecutor.registerHandler('sendPlatformCapabilityState', (payload) => {
        if (!payload?.capabilityId) {
            _error(() => '[QuarkBridge] Invalid payload: capabilityId is required');
            return;
        }

        const newState = payload.newState || {};
        const state = __convertPlatformDataToData(newState);
        if (!state) {
            _error(() => '[QuarkBridge] Invalid capability state');
            return;
        }

        try {
            window.yandex.quarkNative.__notifyPlatformCapabilityStateChanged(payload.capabilityId, state);
            _log(() => `[QuarkBridge] Send platform capability state[${payload.newState}] to ${payload.capabilityId} success handled`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to update state for ${payload.capabilityId}`, error);
        }
    });

    window.__quarkCommandExecutor.registerHandler('sendPlatformCapabilityEvent', (payload) => {
        if (!payload?.capabilityId) {
            _error(() => '[QuarkBridge] Failed to send platform capability event: capabilityId is missing');
            return;
        }
        const event = __convertPlatformDataToData(payload.event);
        if (!event) {
            _error(() => `Failed to send platform capability event to ${payload.capabilityId}: event invalid`);
            return;
        }
        try {
            window.yandex.quarkNative.__notifyPlatformCapabilityEvent(payload.capabilityId, event);
            _log(() => `[QuarkBridge] Send platform capability event ${event} to ${payload.capabilityId} success handled`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to send platform capability event`, error);
        }
    });

    window.__quarkCommandExecutor.registerHandler('notifyAllMainPlatformCapabilitiesAdded', (payload) => {
        try {
            window.yandex.quarkNative.__notifyAllMainPlatformCapabilitiesAdded();
            _log(() => `[QuarkBridge] Notify all main platform capabilities added success handled`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to notify all main platform capabilities added`, error);
        }
    });

    window.__quarkCommandExecutor.registerHandler('registerSupportedFeatures', (payload) => {
        try {
            window.yandex.quarkNative.__updateSupportedFeatures(payload.features);
            _log(() => `[QuarkBridge] Register all supported features: ${payload}`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to register supported feature`, error);
        }
    });

    window.__quarkCommandExecutor.registerHandler('sendDirective', (payload) => {
        const directiveName = payload.directiveName;
        const directiveData = __convertPlatformDataToData(payload.directiveData);
        if (!directiveData) {
            _error(() => `Failed to send directive ${directiveName}: data invalid`);
            return;
        }
        try {
            window.yandex.quarkNative.__sendDirective({
                name: directiveName,
                data: directiveData
            });
            _log(() => `[QuarkBridge] Success send directive ${directiveName}`);
        } catch (error) {
            _error(() => `[QuarkBridge] Failed to send directive ${directiveName}`, error);
        }
    });

    (function() {
        const PlatformCapabilityStatus = {
            NORMAL: 'NORMAL',
            PENDING_ADD: 'PENDING_ADD',
            PENDING_REMOVE: 'PENDING_REMOVE',
            PENDING_UPDATE: 'PENDING_UPDATE'
        };

        const quarkNativeImpl = {

            __callbacks: {
                capabilityState: null,
                capabilityEvent: null,
                addCapability: null,
                removeCapability: null,
                sendDirective: null,
                callDirective: null,
                updateSupportedFeatures: null
            },

            __platformCapabilityInfoById: {},
            __allMainPlatformCapabilitiesAdded: false,
            __getAvailableCapabilitiesResolvers: [],

            __webCapabilities: {},

            __pendingDirectives: [],

            supportedFeatures: [],

            __addPlatformCapability: (capability) => {
                if (!capability?.id) {
                    _error(() => '[QuarkBridge] Invalid capability provided to addPlatformCapability');
                    return;
                }
                const currentCapabilityStatus = quarkNativeImpl.__platformCapabilityInfoById[capability.id]?.status;
                switch (currentCapabilityStatus) {
                    case PlatformCapabilityStatus.PENDING_UPDATE:
                    case PlatformCapabilityStatus.PENDING_ADD:
                    case PlatformCapabilityStatus.NORMAL:
                        _log(() => `[QuarkBridge] Capability ${capability.id} is already being added`);
                        return;
                    case PlatformCapabilityStatus.PENDING_REMOVE:
                        _log(() => `[QuarkBridge] Capability ${capability.id} was being removed, update`);
                        quarkNativeImpl.__platformCapabilityInfoById[capability.id].status = PlatformCapabilityStatus.PENDING_UPDATE;
                        quarkNativeImpl.__platformCapabilityInfoById[capability.id].capability = capability;
                        return;
                    case undefined:
                        _log(() => `[QuarkBridge] Adding new capability ${capability.id}`);
                        quarkNativeImpl.__platformCapabilityInfoById[capability.id] = {
                            capability: capability,
                            status: PlatformCapabilityStatus.PENDING_ADD
                        };
                        if (!quarkNativeImpl.__callbacks.addCapability) {
                            return;
                        }
                        try {
                            quarkNativeImpl.__callbacks.addCapability(capability);
                            quarkNativeImpl.__platformCapabilityInfoById[capability.id].status = PlatformCapabilityStatus.NORMAL;
                            _log(() => `Platform capability ${capability.id} success added`);
                        } catch (error) {
                            _error(() => `Failed to add platform capability ${capability.id}`, error);
                        }
                        return;
                }
            },

            __removePlatformCapability: (capabilityId) => {
                if (!capabilityId) {
                    _error(() => '[QuarkBridge] Invalid capabilityId provided to removePlatformCapability');
                    return;
                }
                const currentCapabilityStatus = quarkNativeImpl.__platformCapabilityInfoById[capabilityId]?.status
                switch (currentCapabilityStatus) {
                    case PlatformCapabilityStatus.PENDING_UPDATE:
                        _log(() => `[QuarkBridge] Capability ${capabilityId} is updated`);
                        quarkNativeImpl.__platformCapabilityInfoById[capabilityId].status = PlatformCapabilityStatus.PENDING_REMOVE;
                        return;
                    case PlatformCapabilityStatus.PENDING_REMOVE:
                        _log(() => `[QuarkBridge] Capability ${capabilityId} is already being removed`);
                        return;
                    case PlatformCapabilityStatus.PENDING_ADD:
                        _log(() => `[QuarkBridge] Removing capability ${capabilityId} that was being added`);
                        delete quarkNativeImpl.__platformCapabilityInfoById[capabilityId];
                        return;
                    case PlatformCapabilityStatus.NORMAL:
                        _log(() => `[QuarkBridge] Removing capability ${capabilityId}`);
                        if (!quarkNativeImpl.__callbacks.removeCapability) {
                            quarkNativeImpl.__platformCapabilityInfoById[capabilityId].status = PlatformCapabilityStatus.PENDING_REMOVE;
                            return;
                        }
                        try {
                            quarkNativeImpl.__callbacks.removeCapability(capabilityId);
                            delete quarkNativeImpl.__platformCapabilityInfoById[capabilityId];
                            _log(() => `Platform capability ${capabilityId} success removed`);
                        } catch (error) {
                            _error(() => `Failed to remove platform capability ${capabilityId}`, error);
                        }
                        return;
                    case undefined:
                        _log(() => `[QuarkBridge] Capability ${capabilityId} not found`);
                        return;
                }
            },

            __notifyPlatformCapabilityStateChanged: (capabilityId, newState) => {
                if (!capabilityId) {
                    _error(() => '[QuarkBridge] Invalid capabilityId provided to notifyPlatformCapabilityStateChanged');
                    return;
                }
                if (!newState) {
                    _error(() => '[QuarkBridge] Invalid newState provided to notifyPlatformCapabilityStateChanged');
                    return;
                }
                const capability = quarkNativeImpl.__platformCapabilityInfoById[capabilityId]?.capability;
                if (!capability) {
                    _warn(() => `[QuarkBridge] Skip new state because capability with id ${capabilityId} not found`);
                    return;
                }
                try {
                    capability.__updateState(newState);
                    if (quarkNativeImpl.__callbacks.capabilityState) {
                        quarkNativeImpl.__callbacks.capabilityState(capabilityId, newState);
                    }
                    _log(() => `Platform capability ${capabilityId} state success provided`);
                } catch (error) {
                    _error(() => `Failed to provide platform capability ${capabilityId} state`, error);
                }
            },

            __notifyPlatformCapabilityEvent: (capabilityId, event) => {
                const capability = quarkNativeImpl.__platformCapabilityInfoById[capabilityId]?.capability;
                if (!capability) {
                    _warn(() => `[QuarkBridge] Skip event ${event} because capability with id ${capabilityId} not found`);
                    return;
                }
                if (quarkNativeImpl.__callbacks.capabilityEvent) {
                    try {
                        quarkNativeImpl.__callbacks.capabilityEvent(capabilityId, event);
                    } catch (error) {
                        _error(() => `Failed to provide platform capability event ${event}`, error);
                    }
                } else {
                    _error(() => `Skip platform capability event ${event}: event callback is null`);
                }
            },

            __notifyAllMainPlatformCapabilitiesAdded: () => {
                if (quarkNativeImpl.__allMainPlatformCapabilitiesAdded) return;
                quarkNativeImpl.__allMainPlatformCapabilitiesAdded = true;
                quarkNativeImpl.__getAvailableCapabilitiesResolvers.forEach(resolve => {
                    try {
                        resolve();
                    } catch (e) {
                        _error(() => '[QuarkBridge] Error resolving promise:', e);
                    }
                });
                quarkNativeImpl.__getAvailableCapabilitiesResolvers = [];
            },

            __sendDirective: (directive) => {
                if (quarkNativeImpl.__callbacks.sendDirective) {
                    try {
                        quarkNativeImpl.__callbacks.sendDirective(directive);
                    } catch (e) {
                        _error(() => `[QuarkBridge] Error send directive ${directive.name}:`, e);
                    }
                } else {
                    quarkNativeImpl.__pendingDirectives.push(directive);
                }
            },

            __updateSupportedFeatures: (supportedFeatures) => {
                quarkNativeImpl.supportedFeatures = supportedFeatures;
                if (quarkNativeImpl.__callbacks.updateSupportedFeatures) {
                    try {
                        quarkNativeImpl.__callbacks.updateSupportedFeatures(supportedFeatures);
                    } catch (e) {
                        _error(() => `[QuarkBridge] Error send supportedFeatures:`, e);
                    }
                }
            },

            getAvailableCapabilities: async () => {
                if (!quarkNativeImpl.__allMainPlatformCapabilitiesAdded) {
                    await new Promise((resolve, reject) => {
                        if (quarkNativeImpl.__allMainPlatformCapabilitiesAdded) {
                            resolve();
                        } else {
                            quarkNativeImpl.__getAvailableCapabilitiesResolvers.push(resolve);
                        }
                    });
                }
                Object.keys(quarkNativeImpl.__platformCapabilityInfoById).forEach(id => {
                    const status = quarkNativeImpl.__platformCapabilityInfoById[id].status;
                    if (status === PlatformCapabilityStatus.PENDING_REMOVE) {
                        _log(() => `[QuarkBridge] Removing capability with ID ${id}`);
                        delete quarkNativeImpl.__platformCapabilityInfoById[id];
                    } else {
                        _log(() => `[QuarkBridge] Changing status of capability ${id} to NORMAL`);
                        quarkNativeImpl.__platformCapabilityInfoById[id].status = PlatformCapabilityStatus.NORMAL;
                    }
                });
                return Object.values(quarkNativeImpl.__platformCapabilityInfoById).map(info => {
                    return info.capability;
                });
            },

            addCapability: (capability) => {
                if (capability.isPlatformCapability || false) {
                    _log(() => `[QuarkBridge] Capability ${capability.id} is platform, skip`);
                    return;
                }
                const capabilityId = capability.id;
                const storedCapability = quarkNativeImpl.__webCapabilities[capabilityId];
                if (storedCapability) {
                    _log(() => `[QuarkBridge] Web capability ${capabilityId} already registered`);
                    return;
                }
                quarkNativeImpl.__webCapabilities[capabilityId] = capability;
                const initialState = quarkNativeImpl.__convertDataToPlatformData(capability.state) || {
                    type: 'json',
                    value: ''
                };
                sendEventToAndroid('registerWebCapability', {
                    id: capabilityId,
                    initialState: initialState,
                    supportedDirectives: capability.supportedDirectives
                });
            },

            removeCapability: (capabilityId) => {
                const capability = quarkNativeImpl.__webCapabilities[capabilityId];
                if (!capability) {
                    _log(() => `[QuarkBridge] Web capability ${capabilityId} not found`);
                    return;
                }
                delete quarkNativeImpl.__webCapabilities[capabilityId];
                sendEventToAndroid('unregisterWebCapability', {
                    id: capabilityId,
                });
            },

            __handleWebCapabilityDirective: (capabilityId, directive) => {
                const capability = quarkNativeImpl.__webCapabilities[capabilityId];
                if (!capability) {
                    _log(() => `[QuarkBridge] Web capability ${capabilityId} not found`);
                    return;
                }
                if (quarkNativeImpl.__callbacks.callDirective) {
                    try {
                        quarkNativeImpl.__callbacks.callDirective(capabilityId, directive);
                    } catch (e) {
                        _error(() => `[QuarkBridge] Error call directive ${directive.name}:`, e);
                    }
                } else {
                    _error(() => `[QuarkBridge] Error call directive ${directive.name}: callback not provided`);
                }
            },

            setGetAvailableCapabilitiesCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided getAvailableCapabilities callback is invalid');
                    return;
                }
                Promise.resolve()
                    .then(() => callback())
                    .then(webCapabilities => {
                        _log(() => `[QuarkBridge] Processing ${webCapabilities.length} web capabilities from callback`);
                        webCapabilities.forEach(webCapability => {
                            quarkNativeImpl.addCapability(webCapability);
                        });
                    })
                    .catch(error => {
                        _error(() => '[QuarkBridge] Error processing web capabilities callback:', error);
                    });
            },

            setSendDirectiveCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided sendDirective callback is invalid');
                    return;
                }
                quarkNativeImpl.__callbacks.sendDirective = callback;
                quarkNativeImpl.__pendingDirectives.forEach(directive => {
                    try {
                        callback(directive);
                    } catch (error) {
                        _error(() => `[QuarkBridge] Error send directive ${directive.name}:`, error);
                    }
                });
                quarkNativeImpl.__pendingDirectives.length = 0;
            },

            setCallDirectiveCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided callDirective callback is invalid');
                    return;
                }
                quarkNativeImpl.__callbacks.callDirective = callback;
            },

            setCapabilityStateCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided capabilityState callback is invalid');
                    return;
                }
                quarkNativeImpl.__callbacks.capabilityState = callback;
            },

            setCapabilityEventCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided capabilityEvent callback is invalid');
                    return;
                }
                quarkNativeImpl.__callbacks.capabilityEvent = callback;
            },

            updateCapabilityState: (capabilityId, state) => {
                const capability = quarkNativeImpl.__webCapabilities[capabilityId];
                if (!capability) {
                    _log(() => `[QuarkBridge] Web capability ${capabilityId} not found`);
                    return;
                }
                const newState = quarkNativeImpl.__convertDataToPlatformData(state) || {
                    type: 'json',
                    value: ''
                };
                sendEventToAndroid('webCapabilityStateChanged', {
                    capabilityId: capabilityId,
                    newState: newState
                });
            },

            provideCapabilityEvent: (capabilityId, event) => {
                const capability = quarkNativeImpl.__webCapabilities[capabilityId];
                if (!capability) {
                    _log(() => `[QuarkBridge] Skip event. Web capability ${capabilityId} not found`);
                    return;
                }
                const convertedEvent = quarkNativeImpl.__convertDataToPlatformData(event)
                if (!convertedEvent) {
                    _log(() => `[QuarkBridge] Skip event with incorrect format`);
                    return;
                }
                sendEventToAndroid('webCapabilityEventReceived', {
                    capabilityId: capabilityId,
                    event: convertedEvent
                });
            },

            __arrayBufferToBase64: (buffer) => {
                const chunks = [];
                const uint8 = new Uint8Array(buffer);
                const chunkSize = 0x8000;
                for (let i = 0; i < uint8.length; i += chunkSize) {
                    const chunk = uint8.subarray(i, Math.min(i + chunkSize, uint8.length));
                    chunks.push(String.fromCharCode.apply(null, chunk));
                }
                return btoa(chunks.join(''));
            },

            __convertDataToPlatformData: (data) => {
                if (!data?.type || !data?.value) {
                    _error(() => `[QuarkBridge] Failed to convert invalid data`);
                    return null;
                }
                let dataValue = '';
                let dataType = data.type;
                try {
                    switch (dataType) {
                        case 'json':
                            dataValue = JSON.stringify(data.value);
                            break;
                        case 'protobuf':
                            dataValue = quarkNativeImpl.__arrayBufferToBase64(data.value);
                            break;
                        default:
                            _error(() => `[QuarkBridge] Unsupported data type: ${dataType}`);
                            return null;
                        }
                } catch (error) {
                    _error(() => `[QuarkBridge] Failed to serialize data body:`, error);
                    return null;
                }
                return {
                    type: dataType,
                    value: dataValue
                };
            },

            callDirective: (capabilityId, directive) => {
                const directiveData = quarkNativeImpl.__convertDataToPlatformData(directive.data);
                if (!directiveData) {
                    _error(() => 'Failed to convert directive data to platform data');
                    return;
                }
                sendEventToAndroid('handlePlatformCapabilityDirective', {
                    capabilityId: capabilityId,
                    directiveName: directive.name,
                    directiveData: directiveData
                });
            },

            __tryActualizePlatformCapabilities: () => {
                if (!quarkNativeImpl.__callbacks.addCapability || !quarkNativeImpl.__callbacks.removeCapability) {
                    return;
                }
                Object.keys(quarkNativeImpl.__platformCapabilityInfoById).forEach(id => {
                    const status = quarkNativeImpl.__platformCapabilityInfoById[id].status;
                    const capability = quarkNativeImpl.__platformCapabilityInfoById[id].capability;
                    switch (status) {
                        case PlatformCapabilityStatus.PENDING_ADD:
                            try {
                                quarkNativeImpl.__callbacks.addCapability(capability);
                                quarkNativeImpl.__platformCapabilityInfoById[id].status = PlatformCapabilityStatus.NORMAL;
                                _log(() => `[QuarkBridge] Platform capability ${capability.id} success added`);
                            } catch (error) {
                                _error(() => `[QuarkBridge] Failed to add platform capability ${capability.id}`, error);
                            }
                            break;
                        case PlatformCapabilityStatus.PENDING_REMOVE:
                            try {
                                quarkNativeImpl.__callbacks.removeCapability(id);
                                delete quarkNativeImpl.__platformCapabilityInfoById[id];
                                _log(() => `[QuarkBridge] Platform capability ${id} successfully removed`);
                            } catch (error) {
                                _error(() => `[QuarkBridge] Failed to remove platform capability ${id}`, error);
                            }
                            break;
                        case PlatformCapabilityStatus.PENDING_UPDATE:
                            try {
                                quarkNativeImpl.__callbacks.removeCapability(id);
                                quarkNativeImpl.__platformCapabilityInfoById[id].status = PlatformCapabilityStatus.PENDING_ADD;
                                quarkNativeImpl.__callbacks.addCapability(capability);
                                quarkNativeImpl.__platformCapabilityInfoById[id].status = PlatformCapabilityStatus.NORMAL;
                                _log(() => `[QuarkBridge] Platform capability ${capability.id} success re added`);
                            } catch (error) {
                                _error(() => `[QuarkBridge] Failed to re add platform capability ${capability.id}`, error);
                            }
                            break;
                    }
                });
            },

            setAddCapabilityCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided addCapability callback is invalid');
                    return;
                }
                quarkNativeImpl.__callbacks.addCapability = callback;
                quarkNativeImpl.__tryActualizePlatformCapabilities();
            },

            setRemoveCapabilityCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided removeCapability callback is invalid');
                    return;
                }
                quarkNativeImpl.__callbacks.removeCapability = callback;
                quarkNativeImpl.__tryActualizePlatformCapabilities();
            },

            setUpdateSupportedFeaturesCallback: (callback) => {
                if (!callback || typeof callback !== 'function') {
                    _error(() => '[QuarkBridge] Provided updateSupportedFeatures callback is invalid');
                    return;
                }
                quarkNativeImpl.__callbacks.updateSupportedFeatures = callback;
                try {
                    callback(quarkNativeImpl.supportedFeatures);
                } catch (e) {
                    _error(() => `[QuarkBridge] Error send supportedFeatures:`, e);
                }
            },

            onReady: () => {
                sendEventToAndroid('webReady', {});
            },

            updateSupportedFeatures: (supportedFeatures) => {
               sendEventToAndroid('updateSupportedFeatures', {
                    supportedFeatures: supportedFeatures,
               });
            }
        };

        if (!window.yandex) {
            _log(() => '[QuarkBridge] Creating window.yandex object as it does not exist');
            window.yandex = {};
        } else {
            _log(() => '[QuarkBridge] window.yandex already exists');
        }

        if (window.__routeWebDirectiveViaNative) {
            quarkNativeImpl.sendDirective = (directive, options) => {
                const directiveData = quarkNativeImpl.__convertDataToPlatformData(directive.data);
                if (!directiveData) {
                    _error(() => 'Failed to convert directive payload to platform data');
                    return;
                }
                sendEventToAndroid('handleDirective', {
                    directiveName: directive.name,
                    directiveData: directiveData
                });
            };
        }

        window.yandex.quarkNative = quarkNativeImpl;

        setTimeout(() => {
            if (!window.yandex.quarkNative.__allMainPlatformCapabilitiesAdded) {
                _warn(() => "[QuarkBridge] Timeout waiting for main platform capabilities initialization");
                window.yandex.quarkNative.__notifyAllMainPlatformCapabilitiesAdded();
            }
        }, 5000);

        _log(() => '[QuarkBridge] JavaScript implementation of QuarkNative has been assigned to window.yandex.quarkNative');
    })();

    _log(() => '[QuarkBridge] Bridge initialization complete');
}

_log(() => '[QuarkBridge] Script loading completed');
