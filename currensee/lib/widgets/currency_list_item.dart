import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../providers/currency_provider.dart';
import '../utils/keyboard_util.dart';
import 'currency_flag_placeholder.dart';
import 'dart:async';
import 'dart:io' show Platform;

class CurrencyListItem extends StatefulWidget {
  final Currency currency;
  final Function(String, double) onValueChanged;
  final bool isBaseCurrency;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;

  const CurrencyListItem({
    super.key,
    required this.currency,
    required this.onValueChanged,
    required this.onTap,
    required this.isBaseCurrency,
    required this.isSelected,
    required this.isEditing,
    required this.onEditStart,
    required this.onEditEnd,
  });

  @override
  State<CurrencyListItem> createState() => _CurrencyListItemState();
}

class _CurrencyListItemState extends State<CurrencyListItem> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _blockValueUpdates = false;
  Timer? _updateDebouncer;
  Timer? _focusDebouncer;
  bool _processingFocus = false;
  bool _isEditing = false;
  DateTime _lastFocusTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateControllerText();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateDebouncer?.cancel();
    _focusDebouncer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[$timestamp] 🎯 Focus changed for ${widget.currency.code}: hasFocus=${_focusNode.hasFocus}');
    
    if (_focusNode.hasFocus) {
      if (!_isEditing) {
        _isEditing = true;
        widget.onEditStart();
        debugPrint('[$timestamp] ✏️ Started editing ${widget.currency.code}');
      }
    } else {
      if (_isEditing) {
        _isEditing = false;
        widget.onEditEnd();
        debugPrint('[$timestamp] ✅ Finished editing ${widget.currency.code}');
        
        // Update value when focus is lost
        if (_controller.text.isEmpty) {
          widget.onValueChanged(widget.currency.code, 0);
          _updateControllerText();
          debugPrint('[$timestamp] 🧹 Empty text, setting value to 0');
        } else {
          // Remove all non-numeric characters except dots and commas
          String cleanText = _controller.text.replaceAll(RegExp(r'[^\d\.,]'), '');
          // Replace commas with dots for parsing
          cleanText = cleanText.replaceAll(',', '.');
          
          // If there are multiple dots, keep only the first one
          final dotIndex = cleanText.indexOf('.');
          if (dotIndex != -1) {
            final afterDot = cleanText.substring(dotIndex + 1).replaceAll('.', '');
            cleanText = cleanText.substring(0, dotIndex + 1) + afterDot;
          }
          
          double? value = double.tryParse(cleanText);
          if (value != null) {
            // Round to 2 decimal places before updating
            value = (value * 100).round() / 100;
            widget.onValueChanged(widget.currency.code, value);
            debugPrint('[$timestamp] ✅ Updated value to $value');
          } else if (_controller.text.isNotEmpty) {
            debugPrint('[$timestamp] ⚠️ Could not parse value from text: $cleanText');
            _updateControllerText();
            debugPrint('[$timestamp] ⚠️ Invalid number format, restoring previous value');
          }
        }
      }
    }
  }

  void _updateControllerText() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[$timestamp] 📝 Updating controller text for ${widget.currency.code}');
    
    if (_isEditing) {
      debugPrint('[$timestamp] ⏩ Skipping update while editing');
      return;
    }

    try {
      // Format the value with comma separators and exactly 2 decimal places
      NumberFormat formatter = NumberFormat('#,##0.00', 'en_US');
      final newText = formatter.format(widget.currency.value);
      
      if (_controller.text != newText) {
        _controller.text = newText;
        debugPrint('[$timestamp] ✅ Updated text to $newText');
      } else {
        debugPrint('[$timestamp] ⏩ Text unchanged, skipping update');
      }
    } catch (e) {
      debugPrint('[$timestamp] ❌ Error formatting value: $e');
      // Fallback to simple formatting if NumberFormat fails
      _controller.text = widget.currency.value.toStringAsFixed(2);
    }
  }

  void _handleTextChanged(String text) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[$timestamp] 📝 Text changed for ${widget.currency.code}: $text');
    
    _updateDebouncer?.cancel();
    _updateDebouncer = Timer(const Duration(milliseconds: 300), () {
      final debounceTimestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[$debounceTimestamp] ⏱️ Debounce timer fired for ${widget.currency.code}');
      
      if (text.isEmpty) {
        widget.onValueChanged(widget.currency.code, 0);
        debugPrint('[$debounceTimestamp] 🧹 Empty text, setting value to 0');
      } else {
        // Remove all non-numeric characters except dots and commas
        String cleanText = text.replaceAll(RegExp(r'[^\d\.,]'), '');
        // Replace commas with dots
        cleanText = cleanText.replaceAll(',', '.');
        
        // If there are multiple dots, keep only the first one
        final dotIndex = cleanText.indexOf('.');
        if (dotIndex != -1) {
          final afterDot = cleanText.substring(dotIndex + 1).replaceAll('.', '');
          cleanText = cleanText.substring(0, dotIndex + 1) + afterDot;
        }
        
        double? value = double.tryParse(cleanText);
        if (value != null) {
          widget.onValueChanged(widget.currency.code, value);
          debugPrint('[$debounceTimestamp] ✅ Updated value to $value');
        } else {
          debugPrint('[$debounceTimestamp] ⚠️ Could not parse value from text: $cleanText');
        }
      }
    });
  }

  @override
  void didUpdateWidget(CurrencyListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[$timestamp] 🔄 Widget updated for ${widget.currency.code}');
    debugPrint('[$timestamp]   Old value: ${oldWidget.currency.value}, New value: ${widget.currency.value}');
    debugPrint('[$timestamp]   Is editing: $_isEditing');
    
    if (!_isEditing && oldWidget.currency.value != widget.currency.value) {
      _updateControllerText();
    } else {
      debugPrint('[$timestamp] ⏩ Skipping update: editing=$_isEditing, value changed=${oldWidget.currency.value != widget.currency.value}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isBaseCurrency 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Flag
              Container(
                width: 36,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: widget.currency.flagUrl.isNotEmpty && widget.currency.flagUrl.startsWith('http')
                  ? Image.network(
                      widget.currency.flagUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return CurrencyFlagPlaceholder(currencyCode: widget.currency.code);
                      },
                    )
                  : CurrencyFlagPlaceholder(currencyCode: widget.currency.code),
              ),
              
              // Currency code and name with base indicator
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.isBaseCurrency)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            Text(
                              widget.currency.code,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: widget.isBaseCurrency ? FontWeight.w700 : FontWeight.w500,
                                color: widget.isBaseCurrency 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.currency.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Currency value
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _handleTextChanged,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: widget.isBaseCurrency ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}