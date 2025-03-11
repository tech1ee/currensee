import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/currency.dart';

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
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatValue(widget.currency.value),
    );
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(CurrencyListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller if not focused to avoid changes while typing
    if (!_isFocused && oldWidget.currency.value != widget.currency.value) {
      _controller.text = _formatValue(widget.currency.value);
    }
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  String _formatValue(double value) {
    // Format with 2 decimal places but remove trailing zeros
    final formatter = NumberFormat('#,##0.##');
    return formatter.format(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.15 : 0.08),
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Currency flag with shadow
              Container(
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
                            widget.currency.code.substring(0, 2),
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
              
              // Currency value input
              Container(
                constraints: const BoxConstraints(minWidth: 110),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                  ],
                  onChanged: (value) {
                    final parsedValue = double.tryParse(
                      value.replaceAll(',', '.'),
                    ) ?? 0.0;
                    widget.onValueChanged(widget.currency.code, parsedValue);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 