module UniversalControllerSpecHelper
  def universal_process(method, action, params)
    send(method, action, params: params)
  end

  def do_create(params)
    universal_process(:post, :create, params)
  end

  def do_show(params)
    universal_process(:get, :show, params)
  end

  def do_index(params)
    universal_process(:get, :index, params)
  end

  def do_update(params)
    universal_process(:put, :update, params)
  end

  def do_destroy(params)
    universal_process(:delete, :destroy, params)
  end
end
