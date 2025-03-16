import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../providers/currency_provider.dart';
import 'dart:async';

class CurrencyListItem extends StatefulWidget {
  final Currency currency;
  final bool isBaseCurrency;
  final Function(String, double) onValueChanged;
  final int index;

  const CurrencyListItem({
    Key? key,
    required this.currency,
    required this.isBaseCurrency,
    required this.onValueChanged,
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
  Timer? _updateDebouncer;

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
    
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isBeingEdited = currencyProvider.currentlyEditedCurrencyCode == widget.currency.code;
    final needsUpdate = oldWidget.currency.code != widget.currency.code || 
                       oldWidget.currency.value != widget.currency.value;
    
    final shouldSkipUpdate = _isFocused || isBeingEdited || _blockValueUpdates || _isUserEditing;
    
    if (needsUpdate && !shouldSkipUpdate) {
      _updateControllerText();
    }
  }
  
  void _updateControllerText() {
    final formattedValue = _formatValue(widget.currency.value);
    if (_controller.text != formattedValue) {
      setState(() {
        _controller.text = formattedValue;
      });
    }
  }

  void _onFocusChange(bool hasFocus) {
    if (hasFocus) {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      currencyProvider.setCurrentlyEditedCurrencyCode(widget.currency.code);
      
      if (widget.currency.value == 0) {
        _controller.clear();
      } else {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
      
      setState(() {
        _isFocused = true;
        _isUserEditing = true;
        _blockValueUpdates = true;
      });
    } else {
      _updateDebouncer?.cancel();
      
      if (_controller.text.isEmpty) {
        widget.onValueChanged(widget.currency.code, 0);
        _updateControllerText();
      } else {
        String cleanText = _controller.text.replaceAll(RegExp(r'[^\d\.,]'), '');
        cleanText = cleanText.replaceAll(',', '.');
        
        double? value = double.tryParse(cleanText);
        if (value != null) {
          widget.onValueChanged(widget.currency.code, value);
        } else if (_controller.text.isNotEmpty) {
          _updateControllerText();
        }
      }
      
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      currencyProvider.clearCurrentlyEditedCurrencyCode();
      
      setState(() {
        _isFocused = false;
        _isUserEditing = false;
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _blockValueUpdates = false;
          });
        }
      });
    }
  }

  String _formatValue(double value) {
    if (value == 0) return '0';
    
    final formatter = NumberFormat.decimalPattern();
    formatter.minimumFractionDigits = 2;  // Always show 2 decimal places
    formatter.maximumFractionDigits = 2;  // Show exactly 2 digits after decimal
    
    if (value.abs() < 0.0001) {
      return value.toStringAsExponential(4);  // Keep precision for very small numbers
    } else if (value.abs() < 0.01) {
      return value.toStringAsFixed(4);  // Keep precision for small numbers
    } else {
      return formatter.format(value);  // Use standard formatting with two decimal places
    }
  }

  @override
  void dispose() {
    _updateDebouncer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isBeingEdited = currencyProvider.currentlyEditedCurrencyCode == widget.currency.code;
    
    if (!_isFocused && !_blockValueUpdates && _controller.text != _formatValue(widget.currency.value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isFocused && !_blockValueUpdates) {
          _updateControllerText();
        }
      });
    }
    
    return Material(
      color: widget.isBaseCurrency 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
          : Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Flag - Fixed width column
            SizedBox(
              width: 36,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  widget.currency.flagUrl,
                  width: 36,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.flag, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Currency code - Fixed width column
            SizedBox(
              width: 60,
              child: Text(
                widget.currency.code,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: widget.isBaseCurrency 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            // Currency name - Flexible width column
            Expanded(
              child: Text(
                widget.currency.name,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Value editor - Expanded width column for large numbers
            Expanded(
              flex: 2,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                autofocus: false,
                decoration: const InputDecoration.collapsed(
                  hintText: '',
                ),
                cursorWidth: 1.5,
                cursorColor: Theme.of(context).colorScheme.primary,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
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
                  
                  _updateDebouncer?.cancel();
                  _updateDebouncer = Timer(const Duration(milliseconds: 300), () {
                    if (!mounted || text.isEmpty) return;
                    
                    // Clean the text and parse the number
                    String cleanText = text.replaceAll(RegExp(r'[^\d\.,]'), '');
                    cleanText = cleanText.replaceAll(',', '.');
                    
                    // Parse with double.parse for better precision with large numbers
                    double? value;
                    try {
                      value = double.parse(cleanText);
                    } catch (e) {
                      print('Error parsing number: $e');
                    }
                    
                    if (value != null) {
                      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
                      currencyProvider.setCurrentlyEditedCurrencyCode(widget.currency.code);
                      
                      widget.onValueChanged(widget.currency.code, value);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 