import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:wanandroid_flutter/entity/article_type_entity.dart';
import 'package:wanandroid_flutter/entity/base_entity.dart';
import 'package:wanandroid_flutter/entity/base_list_entity.dart';
import 'package:wanandroid_flutter/entity/project_entity.dart';
import 'package:wanandroid_flutter/http/index.dart';
import 'package:wanandroid_flutter/page/home/home/bloc/home_index.dart';

import 'article_index.dart';

class ArticleBloc extends Bloc<ArticleEvent, ArticleState> {
  HomeBloc homeBloc;
  StreamSubscription subscription;

  ArticleBloc(this.homeBloc) {
    print('article bloc constra');

    ///等主页的基础数据加载完了后，子页再开始加载数据
    subscription = homeBloc.state.listen((state) {
      if (state is HomeLoaded) {
        print('博文子页：主页加载完成，开始加载子页');
        dispatch(LoadArticle(-1));
      }else if(homeBloc.alredyHomeloaded && currentState == ArticleUnready()){
        print('博文子页：在构造函数之前主页就已经加载完成并可能已经发送了其他bloc state，开始加载子页');
        dispatch(LoadArticle(-1));
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  ArticleState get initialState => ArticleUnready();

  @override
  Stream<ArticleState> mapEventToState(ArticleEvent event) async* {
    if (event is LoadArticle) {
      yield* _mapLoadArticleToState(event.id);
    } else if (event is LoadMoreArticleDatas) {
      yield* _mapLoadMoreArticleDatasToState(
        datas: event.originDatas,
        id: event.id,
        page: event.page,
      );
    } else if (event is CollectArticle) {
      yield* _mapCollectArticleToState(event.id, event.collect);
    }
  }

  Stream<ArticleState> _mapLoadArticleToState(int id) async* {
    try {
      yield ArticleLoading();
      List<ArticleTypeEntity> types = await _getTypes();
      yield ArticleTypesloaded(types);
      ArticleDatasLoaded datasState = await _getArticleDatasState(
        datas: [],
        id: id,
        page: 1,
      );
      yield datasState;
      yield ArticleLoaded();
    } catch (e) {
      yield ArticleLoadError(e);
    }
  }

  Stream<ArticleState> _mapLoadMoreArticleDatasToState(
      {List<ProjectEntity> datas, int id, int page}) async* {
    try {
      yield ArticleLoading();
      ArticleDatasLoaded datasState = await _getArticleDatasState(
        datas: datas,
        id: id,
        page: page,
      );
      yield datasState;
      yield ArticleLoaded();
    } catch (e) {
      yield ArticleLoadError(e);
    }
  }

  Stream<ArticleState> _mapCollectArticleToState(int id, bool collect) async* {
    try {
      yield ArticleLoading();
      if (collect) {
        await CollectApi.collect(id);
      } else {
        await CollectApi.unCollect(id);
      }
      yield ArticleCollectChanged(id, collect);
      yield ArticleLoaded();
    } catch (e) {
      yield ArticleLoadError(e);
    }
  }

  Future<List<ArticleTypeEntity>> _getTypes() async {
    Response response = await ArticleApi.getArticleTypes();
    BaseEntity<List> baseEntity = BaseEntity.fromJson(response.data);
    List<ArticleTypeEntity> parentTypes =
        baseEntity.data.map((e) => ArticleTypeEntity.fromJson(e)).toList();
    parentTypes.map((parent) {
      parent.children =
          parent.children.map((e) => ArticleTypeEntity.fromJson(e)).toList();
    }).toList();
    return parentTypes;
  }

  ///页码从1开始
  ///id : 如果为-1，则加载最新博文，否则加载对应id类型的博文
  Future<ArticleDatasLoaded> _getArticleDatasState(
      {List<ProjectEntity> datas, int id, int page}) async {
    Response response;
    if (id == -1) {
      response = await ArticleApi.getNewArticle(page);
    } else {
      response = await ArticleApi.getArticleList(page, id);
    }

    BaseEntity<Map<String, dynamic>> baseEntity =
        BaseEntity.fromJson(response.data);
    BaseListEntity<List> baseListEntity =
        BaseListEntity.fromJson(baseEntity.data);
    if (datas == null || datas.length == 0) {
      datas =
          baseListEntity.datas.map((e) => ProjectEntity.fromJson(e)).toList();
    } else {
      datas.addAll(
          baseListEntity.datas.map((e) => ProjectEntity.fromJson(e)).toList());
    }

    if (id == -1 && page == 1) {
      //如果是最新博文的第一页，插入置顶文章
      Response response2 = await ArticleApi.getTopArticles();
      BaseEntity<List> baseEntity2 = BaseEntity.fromJson(response2.data);
      List<ProjectEntity> topArticles =
          baseEntity2.data.map((e) => ProjectEntity.fromJson(e)).toList();
      datas.insertAll(0, topArticles);
    }

    return ArticleDatasLoaded(
        datas, baseListEntity.curPage, baseListEntity.pageCount);
  }
}
