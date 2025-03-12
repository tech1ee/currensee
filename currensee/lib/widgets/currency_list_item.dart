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

  const CurrencyListItem({
    Key? key,
    required this.currency,
    required this.isBaseCurrency,
    required this.onValueChanged,
    required this.onLongPress,
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
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.15 : 0.08),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: widget.onLongPress,
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
            
            print('📱 Row tapped for ${widget.currency.code}, requesting focus');
          },
          child: Padding(
            // Increase vertical padding for more space
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side with flag and currency info
                Expanded(
                  flex: 3, // Allocate more space to the left side
                  child: Row(
                    children: [
                      // Currency flag with shadow
                      Container(
                        width: 40,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.currency.flagUrl,
                            width: 40,
                            height: 30,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 40,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    widget.currency.code.length >= 2 
                                        ? widget.currency.code.substring(0, 2)
                                        : widget.currency.code,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Currency info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.currency.code,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 17,
                                    letterSpacing: -0.3,
                                    color: widget.isBaseCurrency
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                if (widget.isBaseCurrency)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6.0),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.currency.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Add a small spacer
                const SizedBox(width: 8),
                
                // Currency value input - now separate from the left content
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    autofocus: false,
                    decoration: const InputDecoration.collapsed(hintText: ''),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    onTap: () {
                      // Don't hide keyboard when tapping another field
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
        ),
      ),
    );
  }
} 