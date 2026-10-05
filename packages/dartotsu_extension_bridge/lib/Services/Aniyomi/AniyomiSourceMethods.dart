import '../../Extensions/BridgeSourceMethods.dart';
import '../../dartotsu_extension_bridge.dart';
import '../../Logger.dart';
import '../Mangayomi/Eval/dart/model/filter.dart';

class AniyomiSourceMethods<T extends Source> extends BridgeSourceMethods<T> {
  AniyomiSourceMethods(super.source, super.bridge);

  @override
  Future<String?> getNovelContent(DEpisode episode) async {
    throw UnimplementedError();
  }

  @override
  Future<Pages> search(String query, int page, List<dynamic> filters) async {
    final mappedFilters = filters.map((f) {
      if (f is Map) return f;
      return _mapClassToAniyomiFilter(f);
    }).where((f) => f != null).toList();

    final result = await bridge.call<Map<String, dynamic>>('search', {
      'sourceId': source.id,
      'isAnime': isAnime,
      'query': query,
      'page': page,
      'filters': mappedFilters,
    });

    return Pages.fromJson(result);
  }

  @override
  Future<List<dynamic>> getFilterList() async {
    try {
      final result = await bridge.call<List<dynamic>>('getFilterList', {
        'sourceId': source.id,
        'isAnime': isAnime,
      });
      return result
          .map((f) => _mapAniyomiFilterToClass(Map<dynamic, dynamic>.from(f as Map)))
          .where((f) => f != null)
          .toList();
    } catch (e) {
      Logger.log('AniyomiSourceMethods getFilterList error: $e');
      return [];
    }
  }

  dynamic _mapAniyomiFilterToClass(Map<dynamic, dynamic> map) {
    final name = map['name'] as String? ?? '';
    final type = map['type'] as String? ?? '';
    final state = map['state'];
    final values = map['values'] as List<dynamic>?;

    switch (type) {
      case 'Header':
        return HeaderFilter(name, 'HeaderFilter', type: '');
      case 'Separator':
        return SeparatorFilter('SeparatorFilter', type: '');
      case 'CheckBox':
        return CheckBoxFilter(
          '', name, name, 'CheckBox',
          state: state is bool ? state : false,
        );
      case 'TriState':
        return TriStateFilter(
          '', name, name, 'TriState',
          state: state is int ? state : 0,
        );
      case 'Select':
        final selectOptions = values
                ?.map((v) => SelectFilterOption(v.toString(), v.toString(), 'SelectOption'))
                .toList() ??
            [];
        return SelectFilter(
          '', name, state is int ? state : 0, selectOptions, 'SelectFilter',
        );
      case 'Sort':
        final selectOptions = values
                ?.map((v) => SelectFilterOption(v.toString(), v.toString(), 'SelectOption'))
                .toList() ??
            [];
        SortState sortState;
        if (state is Map) {
          sortState = SortState(
            state['index'] is int ? state['index'] : 0,
            state['ascending'] is bool ? state['ascending'] : true,
            'SortState',
          );
        } else {
          sortState = SortState(0, true, 'SortState');
        }
        return SortFilter(
          '', name, sortState, selectOptions, 'SortFilter',
        );
      case 'Text':
        return TextFilter(
          '', name, 'TextFilter',
          state: state is String ? state : '',
        );
      case 'Group':
        final subFilters = (state as List<dynamic>?)
                ?.map((sub) => _mapAniyomiFilterToClass(Map<dynamic, dynamic>.from(sub as Map)))
                .where((f) => f != null)
                .toList() ??
            [];
        return GroupFilter(
          '', name, subFilters, 'GroupFilter',
        );
      default:
        return null;
    }
  }

  Map<String, dynamic>? _mapClassToAniyomiFilter(dynamic filter) {
    if (filter is HeaderFilter) {
      return {
        'name': filter.name,
        'type': 'Header',
        'state': null,
      };
    } else if (filter is SeparatorFilter) {
      return {
        'name': '',
        'type': 'Separator',
        'state': null,
      };
    } else if (filter is CheckBoxFilter) {
      return {
        'name': filter.name,
        'type': 'CheckBox',
        'state': filter.state,
      };
    } else if (filter is TriStateFilter) {
      return {
        'name': filter.name,
        'type': 'TriState',
        'state': filter.state,
      };
    } else if (filter is SelectFilter) {
      return {
        'name': filter.name,
        'type': 'Select',
        'state': filter.state,
        'values': filter.values
            .map((v) => v is SelectFilterOption ? v.name : v.toString())
            .toList(),
      };
    } else if (filter is SortFilter) {
      return {
        'name': filter.name,
        'type': 'Sort',
        'state': {
          'index': filter.state.index,
          'ascending': filter.state.ascending,
        },
        'values': filter.values
            .map((v) => v is SelectFilterOption ? v.name : v.toString())
            .toList(),
      };
    } else if (filter is TextFilter) {
      return {
        'name': filter.name,
        'type': 'Text',
        'state': filter.state,
      };
    } else if (filter is GroupFilter) {
      return {
        'name': filter.name,
        'type': 'Group',
        'state': filter.state
            .map((sub) => _mapClassToAniyomiFilter(sub))
            .where((f) => f != null)
            .toList(),
      };
    }
    return null;
  }
}
