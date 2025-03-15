import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../providers/currency_provider.dart';
import '../utils/keyboard_util.dart';

class CurrencyListItem extends StatefulWidget {
  final Currency currency;
  final bool isBaseCurrency;
  final Function(String, double) onValueChanged;
  final VoidCallback onLongPress;
  final VoidCallback onSetAsBase;
  final int index;

  const CurrencyListItem({
    Key? key,
    required this.currency,
    required this.isBaseCurrency,
    required this.onValueChanged,
    required this.onLongPress,
    required this.onSetAsBase,
    required this.index,
  }) : super(key: key);

  @override
  State<CurrencyListItem> createState() => _CurrencyListItemState();
}

class _CurrencyListItemState extends State<CurrencyListItem> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _isUserEditing = false;
  bool _blockValueUpdates = false;
  
  // Feature flag to completely prevent updates while editing
  static const bool FREEZE_DURING_EDIT = true;

  @override
  void initState() {
    super.initState();
    
    _controller = TextEditingController(text: _formatValue(widget.currency.value));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      _onFocusChange(_focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(CurrencyListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Get the currency provider to check if this currency is being edited
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isBeingEdited = currencyProvider.currentlyEditedCurrencyCode == widget.currency.code;
    
    // Check if we need to update the display value
    final needsUpdate = oldWidget.currency.code != widget.currency.code || 
                        oldWidget.currency.value != widget.currency.value;
    
    print('🔍 didUpdateWidget called for ${widget.currency.code}:');
    print('   Old value: ${oldWidget.currency.value}, New value: ${widget.currency.value}');
    print('   Is focused: $_isFocused, Is being edited: $isBeingEdited, Needs update: $needsUpdate');
    print('   Block updates: $_blockValueUpdates');
    
    // CRITICAL FIX: Stronger protection against updates during editing
    final shouldSkipUpdate = _isFocused || isBeingEdited || _blockValueUpdates || _isUserEditing;
    
    if (needsUpdate && !shouldSkipUpdate) {
      print('   📝 Updating text for ${widget.currency.code} immediately');
      _updateControllerText();
    } else {
      print('   ⏩ No immediate update needed - user is editing or updates blocked');
    }
  }
  
  void _updateControllerText() {
    final formattedValue = _formatValue(widget.currency.value);
    print('🔄 Updating text for ${widget.currency.code}:');
    print('   Raw value: ${widget.currency.value}');
    print('   Formatted: $formattedValue');
    print('   Current text: "${_controller.text}"');
    
    if (_controller.text != formattedValue) {
      print('   ✅ Text change needed, updating display');
      // Use setState to ensure the UI updates
      setState(() {
        _controller.text = formattedValue;
      });
    } else {
      print('   ⏩ No text change needed');
    }
  }

  void _onFocusChange(bool hasFocus) {
    print('\n🔎🔎🔎 FOCUS CHANGE FOR ${widget.currency.code}: ${hasFocus ? 'GAINED' : 'LOST'} 🔎🔎🔎');
    
    if (hasFocus) {
      print('   📱 Field gained focus');
      // Notify the currency provider that this field is focused
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      currencyProvider.setCurrentlyEditedCurrencyCode(widget.currency.code);
      
      // If the value is zero, clear the field to make it easier for the user to enter a new value
      if (widget.currency.value == 0) {
        print('   🧹 Currency value is 0, clearing text field');
        _controller.clear();
      } else {
        // Select all text for easy replacement
        print('   🔤 Selecting all text for easy editing');
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
      
      setState(() {
        _isFocused = true;
        _isUserEditing = true; // Mark as being edited when focus is gained
        _blockValueUpdates = true; // Block value updates while focused
      });
    } else {
      print('   📴 Field lost focus');
      
      // If the text is empty when losing focus, reset to zero
      if (_controller.text.isEmpty) {
        print('   0️⃣ Text field is empty, setting to zero');
        widget.onValueChanged(widget.currency.code, 0);
        _updateControllerText(); // Update the controller text immediately
      } else {
        // Ensure there's a valid value in the field
        String cleanText = _controller.text.replaceAll(RegExp(r'[^\d\.,]'), '');
        cleanText = cleanText.replaceAll(',', '.');
        
        double? value = double.tryParse(cleanText);
        if (value != null) {
          print('   🔄 Reformatting value on focus loss: $value');
          widget.onValueChanged(widget.currency.code, value);
        } else if (_controller.text.isNotEmpty) {
          print('   ⚠️ Invalid value on focus loss, resetting to current value');
          _updateControllerText(); // Reset to the current currency value
        }
      }
      
      // Clear the currently edited currency code but DON'T force keyboard hide
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      currencyProvider.clearCurrentlyEditedCurrencyCode();
      
      setState(() {
        _isFocused = false;
        _isUserEditing = false; // Clear editing flag when focus is lost
      });
      
      // Allow value updates again after a short delay
      // Do this outside setState to avoid unnecessary rebuilds
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _blockValueUpdates = false;
          });
        }
      });
    }
    
    print('🔎🔎🔎 FOCUS CHANGE COMPLETE 🔎🔎🔎\n');
  }

  String _formatValue(double value) {
    // Handle zero
    if (value == 0) return '0';
    
    // Handle different value ranges with appropriate precision
    if (value.abs() < 0.0001) {
      // Very small values
      return value.toStringAsFixed(6);
    } else if (value.abs() < 0.01) {
      return value.toStringAsFixed(4);
    } else if (value.abs() < 1) {
      return value.toStringAsFixed(2);
    } else if (value.abs() < 1000) {
      // Use a formatter with up to 2 decimal places for normal values
      final formatter = NumberFormat('#,##0.##');
      return formatter.format(value);
    } else {
      // For very large values, use fewer decimals
      final formatter = NumberFormat('#,###');
      return formatter.format(value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(() {
      // Empty listener removal since we're using an anonymous function in initState
    });
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Listen for changes to the currently edited currency
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isBeingEdited = currencyProvider.currentlyEditedCurrencyCode == widget.currency.code;
    
    // CRITICAL FIX: Check for value changes and force update the controller 
    // anytime the currency value changes, unless we're currently editing it
    if (!_isFocused && !_blockValueUpdates && _controller.text != _formatValue(widget.currency.value)) {
      // Using post frame callback to avoid build-time setState issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isFocused && !_blockValueUpdates) {
          _updateControllerText();
        }
      });
    }
    
    final content = InkWell(
      onTap: () {
        // Don't hide the keyboard when changing focus
        FocusScope.of(context).requestFocus(_focusNode);
        
        // Set edited currency and block unwanted updates
        final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
        currencyProvider.setCurrentlyEditedCurrencyCode(widget.currency.code);
        
        setState(() {
          _blockValueUpdates = true;
          _isUserEditing = true;
        });
        
        if (widget.currency.value == 0) {
          _controller.clear();
        } else {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        }
      },
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Flag
                Image.network(
                  widget.currency.flagUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.flag, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                // Currency code and name
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.currency.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            widget.currency.code,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (widget.isBaseCurrency)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Base',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Value editor
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          autofocus: false,
                          // Absolutely minimal decoration
                          decoration: const InputDecoration.collapsed(
                            hintText: '',
                          ),
                          cursorWidth: 1.5,
                          cursorColor: Theme.of(context).colorScheme.primary,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.5,
                            // Highlight text when editing
                            color: isBeingEdited && _isFocused 
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          onChanged: (text) {
                            if (!_blockValueUpdates) {
                              setState(() {
                                _blockValueUpdates = true;
                                _isUserEditing = true;
                              });
                            }
                            
                            if (text.isEmpty) return;
                            
                            final cleanText = text.replaceAll(',', '.');
                            final value = double.tryParse(cleanText);
                            
                            if (value != null) {
                              final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
                              currencyProvider.setCurrentlyEditedCurrencyCode(widget.currency.code);
                              
                              Future.microtask(() {
                                if (mounted) {
                                  widget.onValueChanged(widget.currency.code, value);
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Swipe hint indicator
          Positioned(
            right: 5,
            top: 0,
            bottom: 0,
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    size: 20,
                  ),
                  Icon(
                    Icons.more_vert,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    
    return Material(
      color: widget.isBaseCurrency 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
          : Colors.transparent,
      child: content,
    );
  }
} 